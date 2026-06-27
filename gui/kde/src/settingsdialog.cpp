#include "settingsdialog.h"

#include <QCheckBox>
#include <QComboBox>
#include <QDialogButtonBox>
#include <QFormLayout>
#include <QGroupBox>
#include <QLabel>
#include <QPushButton>
#include <QSettings>
#include <QVBoxLayout>

namespace {
const char *kKeyQuality    = "audio/qualityLevel"; // int: 0=128, 1=320, 2=FLAC
const char *kKeyReplayGain = "audio/replayGain";   // bool: loudness normalization
const char *kKeyTray       = "behavior/closeToTray";
const char *kKeyDevice     = "audio/outputDevice"; // string: device id ("" = default)
const char *kKeyGapless    = "audio/gapless";      // bool: gapless playback
const char *kKeyCrossfade  = "audio/crossfadeMs";  // int: 0/3000/6000/12000

QSettings openIni(const QString &path) { return QSettings(path, QSettings::IniFormat); }
} // namespace

int SettingsDialog::loadQuality(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    int v = s.value(kKeyQuality, 0).toInt(); // default: Normal (MP3_128)
    return v < 0 ? 0 : (v > 2 ? 2 : v);
}

bool SettingsDialog::loadReplayGain(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    return s.value(kKeyReplayGain, false).toBool(); // default: off
}

bool SettingsDialog::loadCloseToTray(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    return s.value(kKeyTray, true).toBool();      // default: keep playing in tray
}

QString SettingsDialog::loadOutputDevice(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    return s.value(kKeyDevice, QString()).toString(); // default: system default
}

bool SettingsDialog::loadGapless(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    return s.value(kKeyGapless, false).toBool();  // default: off
}

int SettingsDialog::loadCrossfadeMs(const QString &iniPath) {
    QSettings s = openIni(iniPath);
    int v = s.value(kKeyCrossfade, 0).toInt();    // default: off
    return v < 0 ? 0 : v;
}

SettingsDialog::SettingsDialog(const QString &iniPath,
                               const QVector<AudioDevice> &devices,
                               const QString &currentDeviceId, QWidget *parent)
    : QDialog(parent), m_iniPath(iniPath), m_initialDevice(currentDeviceId) {
    setWindowTitle(QStringLiteral("OpenDeezer Settings"));
    setModal(true);

    auto *root = new QVBoxLayout(this);

    // ---- Audio ----
    auto *audioBox  = new QGroupBox(QStringLiteral("Audio"));
    auto *audioForm = new QFormLayout(audioBox);
    m_quality = new QComboBox;
    m_quality->addItem(QStringLiteral("Normal — MP3 128 kbps"), 0);
    m_quality->addItem(QStringLiteral("High — MP3 320 kbps"), 1);
    m_quality->addItem(QStringLiteral("HiFi — FLAC lossless (falls back to MP3)"), 2);
    m_quality->setCurrentIndex(loadQuality(m_iniPath));
    audioForm->addRow(QStringLiteral("Streaming quality"), m_quality);
    m_replayGain = new QCheckBox(QStringLiteral("Normalize loudness (ReplayGain)"));
    m_replayGain->setChecked(loadReplayGain(m_iniPath));
    audioForm->addRow(QString(), m_replayGain);

    // Output device — populated from the live device list passed in. The current
    // selection prefers the engine's active device, then the system default.
    m_device = new QComboBox;
    if (devices.isEmpty()) {
        m_device->addItem(QStringLiteral("System default"), QString());
    } else {
        for (const AudioDevice &d : devices) {
            QString label = d.name.isEmpty() ? QStringLiteral("System default") : d.name;
            if (d.isDefault)
                label += QStringLiteral("  (default)");
            m_device->addItem(label, d.id);
        }
        int sel = m_device->findData(currentDeviceId);
        if (sel < 0)
            for (int i = 0; i < devices.size(); ++i)
                if (devices[i].isDefault) { sel = i; break; }
        if (sel >= 0)
            m_device->setCurrentIndex(sel);
    }
    audioForm->addRow(QStringLiteral("Output device"), m_device);

    // Gapless + crossfade. Crossfade overlaps adjacent tracks; gapless butts
    // them with no silence. Both rely on the engine preloading the next track.
    m_gapless = new QCheckBox(QStringLiteral("Gapless playback"));
    m_gapless->setChecked(loadGapless(m_iniPath));
    audioForm->addRow(QString(), m_gapless);

    m_crossfade = new QComboBox;
    m_crossfade->addItem(QStringLiteral("Off"), 0);
    m_crossfade->addItem(QStringLiteral("3 seconds"), 3000);
    m_crossfade->addItem(QStringLiteral("6 seconds"), 6000);
    m_crossfade->addItem(QStringLiteral("12 seconds"), 12000);
    {
        const int xf = loadCrossfadeMs(m_iniPath);
        int sel = m_crossfade->findData(xf);
        m_crossfade->setCurrentIndex(sel < 0 ? 0 : sel);
    }
    audioForm->addRow(QStringLiteral("Crossfade"), m_crossfade);
    root->addWidget(audioBox);

    // ---- Behaviour ----
    auto *behBox  = new QGroupBox(QStringLiteral("Behaviour"));
    auto *behLay  = new QVBoxLayout(behBox);
    m_tray = new QCheckBox(QStringLiteral("Keep playing in the background "
                                          "(close to tray)"));
    m_tray->setChecked(loadCloseToTray(m_iniPath));
    auto *hint = new QLabel(QStringLiteral(
        "When enabled, closing the window hides it to the system tray and the "
        "music keeps playing. Use the tray icon to restore or quit."));
    hint->setWordWrap(true);
    QFont hf = hint->font();
    hf.setPointSize(qMax(1, hf.pointSize() - 1));
    hint->setFont(hf);
    behLay->addWidget(m_tray);
    behLay->addWidget(hint);
    root->addWidget(behBox);

    auto *buttons = new QDialogButtonBox(QDialogButtonBox::Ok | QDialogButtonBox::Cancel);
    // Deezer-purple accent on the default action.
    buttons->button(QDialogButtonBox::Ok)->setStyleSheet(
        QStringLiteral("QPushButton{background:#A238FF;color:white;"
                       "padding:5px 16px;border-radius:4px;}"));
    root->addWidget(buttons);

    connect(buttons, &QDialogButtonBox::accepted, this, [this] { save(); accept(); });
    connect(buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void SettingsDialog::save() {
    const int     level = m_quality->currentData().toInt();
    const bool    rg    = m_replayGain->isChecked();
    const bool    tray  = m_tray->isChecked();
    const QString dev   = m_device->currentData().toString();
    const bool    gap   = m_gapless->isChecked();
    const int     xf    = m_crossfade->currentData().toInt();

    QSettings s = openIni(m_iniPath);
    s.setValue(kKeyQuality, level);
    s.setValue(kKeyReplayGain, rg);
    s.setValue(kKeyTray, tray);
    s.setValue(kKeyDevice, dev);
    s.setValue(kKeyGapless, gap);
    s.setValue(kKeyCrossfade, xf);
    s.sync();

    emit qualityChanged(level);
    emit replayGainChanged(rg);
    emit closeToTrayChanged(tray);
    // Re-applying the same output device restarts audio with an audible glitch,
    // so only emit when it actually changed.
    if (dev != m_initialDevice)
        emit outputDeviceChanged(dev);
    emit gaplessChanged(gap);
    emit crossfadeChanged(xf);
}
