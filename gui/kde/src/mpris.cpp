#include "mpris.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QVariant>

namespace {
const char *kPath    = "/org/mpris/MediaPlayer2";
const char *kService = "org.mpris.MediaPlayer2.opendeezer";
const char *kPlayerIf = "org.mpris.MediaPlayer2.Player";
const char *kPropsIf  = "org.freedesktop.DBus.Properties";

// MPRIS trackid must be a valid D-Bus object path: only [A-Za-z0-9_] segments.
QString trackPath(const QString &id) {
    QString safe;
    for (const QChar c : id)
        safe += (c.isLetterOrNumber() || c == '_') ? c : QChar('_');
    if (safe.isEmpty())
        safe = QStringLiteral("none");
    return QStringLiteral("/org/mpris/MediaPlayer2/opendeezer/track/") + safe;
}
} // namespace

// --- MprisRoot -------------------------------------------------------------
MprisRoot::MprisRoot(MprisController *c) : QDBusAbstractAdaptor(c), m_c(c) {}
void MprisRoot::Raise() { emit m_c->raiseRequested(); }
void MprisRoot::Quit()  { emit m_c->quitRequested(); }

// --- MprisPlayer -----------------------------------------------------------
MprisPlayer::MprisPlayer(MprisController *c) : QDBusAbstractAdaptor(c), m_c(c) {}

QString     MprisPlayer::playbackStatus() const { return m_c->status(); }
QVariantMap MprisPlayer::metadata() const       { return m_c->metadata(); }
qlonglong   MprisPlayer::position() const        { return m_c->positionUs(); }
double      MprisPlayer::volume() const          { return m_c->volume(); }
void        MprisPlayer::setVolume(double v)      { emit m_c->volumeChangeRequested(v); }

void MprisPlayer::PlayPause() { emit m_c->playPauseRequested(); }
void MprisPlayer::Play()      { emit m_c->playRequested(); }
void MprisPlayer::Pause()     { emit m_c->pauseRequested(); }
void MprisPlayer::Stop()      { emit m_c->stopRequested(); }
void MprisPlayer::Next()      { emit m_c->nextRequested(); }
void MprisPlayer::Previous()  { emit m_c->prevRequested(); }
void MprisPlayer::Seek(qlonglong offsetUs) { emit m_c->seekRequested(offsetUs); }
void MprisPlayer::SetPosition(const QDBusObjectPath &, qlonglong posUs) {
    emit m_c->setPositionRequested(posUs);
}
void MprisPlayer::OpenUri(const QString &) {}

// --- MprisController -------------------------------------------------------
MprisController::MprisController(QObject *parent) : QObject(parent) {
    // Adaptors must be children of the object registered on the bus.
    new MprisRoot(this);
    new MprisPlayer(this);
}

bool MprisController::registerOnBus() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected())
        return false;
    // Export the object (and its adaptors' interfaces) first, then claim the name.
    if (!bus.registerObject(QString::fromLatin1(kPath), this))
        return false;
    if (!bus.registerService(QString::fromLatin1(kService)))
        return false;
    m_onBus = true;
    return true;
}

QVariantMap MprisController::metadata() const {
    QVariantMap m;
    m[QStringLiteral("mpris:trackid")] =
        QVariant::fromValue(QDBusObjectPath(trackPath(m_trackId)));
    m[QStringLiteral("mpris:length")]  = static_cast<qlonglong>(m_lengthMs) * 1000;
    if (!m_title.isEmpty())
        m[QStringLiteral("xesam:title")] = m_title;
    if (!m_artist.isEmpty())
        m[QStringLiteral("xesam:artist")] = QStringList{m_artist};
    if (!m_album.isEmpty())
        m[QStringLiteral("xesam:album")] = m_album;
    if (!m_artUrl.isEmpty())
        m[QStringLiteral("mpris:artUrl")] = m_artUrl;
    return m;
}

void MprisController::emitPlayerProps(const QVariantMap &changed) {
    if (!m_onBus)
        return;
    QDBusMessage msg = QDBusMessage::createSignal(
        QString::fromLatin1(kPath), QString::fromLatin1(kPropsIf),
        QStringLiteral("PropertiesChanged"));
    msg << QString::fromLatin1(kPlayerIf) << changed << QStringList();
    QDBusConnection::sessionBus().send(msg);
}

void MprisController::updateMetadata(const QString &title, const QString &artist,
                                    const QString &album, const QString &artUrl,
                                    qint64 lengthMs, const QString &trackId) {
    m_title = title; m_artist = artist; m_album = album;
    m_artUrl = artUrl; m_lengthMs = lengthMs; m_trackId = trackId;
    m_positionMs = 0;
    emitPlayerProps({{QStringLiteral("Metadata"), metadata()}});
    notifySeeked(0); // new track -> position discontinuity back to 0
}

void MprisController::updateStatus(const QString &status) {
    if (status == m_status)
        return;
    m_status = status;
    emitPlayerProps({{QStringLiteral("PlaybackStatus"), m_status}});
}

void MprisController::updatePosition(qint64 ms) { m_positionMs = ms; }

void MprisController::updateVolume(double v) {
    if (qFuzzyCompare(v + 1.0, m_volume + 1.0))
        return;
    m_volume = v;
    emitPlayerProps({{QStringLiteral("Volume"), m_volume}});
}

void MprisController::notifySeeked(qint64 ms) {
    m_positionMs = ms;
    if (!m_onBus)
        return;
    QDBusMessage msg = QDBusMessage::createSignal(
        QString::fromLatin1(kPath), QString::fromLatin1(kPlayerIf),
        QStringLiteral("Seeked"));
    msg << static_cast<qlonglong>(ms) * 1000;
    QDBusConnection::sessionBus().send(msg);
}
