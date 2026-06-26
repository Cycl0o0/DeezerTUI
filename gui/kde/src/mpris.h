// OpenDeezer — MPRIS2 (org.mpris.MediaPlayer2) bridge over QtDBus.
//
// MPRIS2 is the freedesktop standard that the Plasma "Media Player" applet,
// the system tray, the lock-screen and the multimedia keys all speak. Owning
// the bus name org.mpris.MediaPlayer2.opendeezer on the *session* bus makes the
// now-playing track show up in the system overlay and lets those surfaces drive
// transport (play/pause/next/prev/seek) — all wired back to MainWindow's own
// existing handlers via the signals below; this class adds no playback logic.
//
// Layout follows the spec: a single object at /org/mpris/MediaPlayer2 carrying
// two interfaces, implemented as two QDBusAbstractAdaptor children of one
// MprisController QObject. The controller holds the published state (metadata,
// status, position, volume), answers the D-Bus property reads, and emits
// PropertiesChanged / Seeked manually (adaptors don't do it automatically).
#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>

class MprisController;

// --- org.mpris.MediaPlayer2 (root) -----------------------------------------
class MprisRoot : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2")
    Q_PROPERTY(QString Identity READ identity)
    Q_PROPERTY(QString DesktopEntry READ desktopEntry)
    Q_PROPERTY(bool CanQuit READ canQuit)
    Q_PROPERTY(bool CanRaise READ canRaise)
    Q_PROPERTY(bool HasTrackList READ hasTrackList)
    Q_PROPERTY(bool Fullscreen READ fullscreen)
    Q_PROPERTY(bool CanSetFullscreen READ canSetFullscreen)
    Q_PROPERTY(QStringList SupportedUriSchemes READ supportedUriSchemes)
    Q_PROPERTY(QStringList SupportedMimeTypes READ supportedMimeTypes)
public:
    explicit MprisRoot(MprisController *c);

    QString     identity() const { return QStringLiteral("OpenDeezer"); }
    QString     desktopEntry() const { return QStringLiteral("org.opendeezer.OpenDeezer"); }
    bool        canQuit() const { return true; }
    bool        canRaise() const { return true; }
    bool        hasTrackList() const { return false; }
    bool        fullscreen() const { return false; }
    bool        canSetFullscreen() const { return false; }
    QStringList supportedUriSchemes() const { return {}; }
    QStringList supportedMimeTypes() const { return {}; }

public slots:
    void Raise();
    void Quit();

private:
    MprisController *m_c;
};

// --- org.mpris.MediaPlayer2.Player -----------------------------------------
class MprisPlayer : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.mpris.MediaPlayer2.Player")
    Q_PROPERTY(QString PlaybackStatus READ playbackStatus)
    Q_PROPERTY(QVariantMap Metadata READ metadata)
    Q_PROPERTY(qlonglong Position READ position)        // microseconds
    Q_PROPERTY(double Rate READ rate WRITE setRate)
    Q_PROPERTY(double MinimumRate READ minimumRate)
    Q_PROPERTY(double MaximumRate READ maximumRate)
    Q_PROPERTY(double Volume READ volume WRITE setVolume)
    Q_PROPERTY(bool CanGoNext READ canGoNext)
    Q_PROPERTY(bool CanGoPrevious READ canGoPrevious)
    Q_PROPERTY(bool CanPlay READ canPlay)
    Q_PROPERTY(bool CanPause READ canPause)
    Q_PROPERTY(bool CanSeek READ canSeek)
    Q_PROPERTY(bool CanControl READ canControl)
public:
    explicit MprisPlayer(MprisController *c);

    QString     playbackStatus() const;
    QVariantMap metadata() const;
    qlonglong   position() const;     // µs
    double      rate() const { return 1.0; }
    void        setRate(double) {}
    double      minimumRate() const { return 1.0; }
    double      maximumRate() const { return 1.0; }
    double      volume() const;
    void        setVolume(double v);
    bool        canGoNext() const { return true; }
    bool        canGoPrevious() const { return true; }
    bool        canPlay() const { return true; }
    bool        canPause() const { return true; }
    bool        canSeek() const { return true; }
    bool        canControl() const { return true; }

public slots:
    void PlayPause();
    void Play();
    void Pause();
    void Stop();
    void Next();
    void Previous();
    void Seek(qlonglong offsetUs);                        // relative
    void SetPosition(const QDBusObjectPath &id, qlonglong posUs);
    void OpenUri(const QString &uri);

signals:
    void Seeked(qlonglong positionUs);

private:
    MprisController *m_c;
};

// --- Backend object registered on the bus ----------------------------------
class MprisController : public QObject {
    Q_OBJECT
public:
    explicit MprisController(QObject *parent = nullptr);

    // Own the bus name + register the object. Returns false when there is no
    // usable session bus (e.g. a headless/CI run) — callers degrade gracefully.
    bool registerOnBus();

    // ---- state pushed in by MainWindow -----------------------------------
    void updateMetadata(const QString &title, const QString &artist,
                        const QString &album, const QString &artUrl,
                        qint64 lengthMs, const QString &trackId);
    void updateStatus(const QString &status);   // "Playing"/"Paused"/"Stopped"
    void updatePosition(qint64 ms);             // no signal (per spec)
    void updateVolume(double v);                // 0..1
    void notifySeeked(qint64 ms);               // discontinuous jump -> Seeked

    // ---- reads used by the adaptors --------------------------------------
    QString     status() const { return m_status; }
    QVariantMap metadata() const;
    qint64      positionUs() const { return m_positionMs * 1000; }
    double      volume() const { return m_volume; }
    bool        onBus() const { return m_onBus; }

signals:
    // Emitted from D-Bus method calls; MainWindow connects these to its own
    // existing transport handlers — keeping playback logic in one place.
    void raiseRequested();
    void quitRequested();
    void playPauseRequested();
    void playRequested();
    void pauseRequested();
    void stopRequested();
    void nextRequested();
    void prevRequested();
    void seekRequested(qlonglong offsetUs);
    void setPositionRequested(qlonglong posUs);
    void volumeChangeRequested(double v);

private:
    void emitPlayerProps(const QVariantMap &changed);

    bool    m_onBus = false;
    QString m_status = QStringLiteral("Stopped");
    QString m_title, m_artist, m_album, m_artUrl, m_trackId;
    qint64  m_lengthMs = 0;
    qint64  m_positionMs = 0;
    double  m_volume = 1.0;
};
