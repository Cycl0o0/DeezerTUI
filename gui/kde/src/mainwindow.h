// OpenDeezer — native KDE / Qt6 Widgets front-end.
//
// The whole engine (login, browse, Blowfish decrypt, MP3 decode, ALSA playback)
// is the Go core compiled to a C static archive (lib/libdeezercore.a) and linked
// in-process. This file is UI only: a QMainWindow with a QListWidget sidebar, a
// QStackedWidget of content pages (track table / playlist grid / search), and a
// bottom transport bar. Every blocking DZ* call is marshalled onto a worker via
// QtConcurrent::run and the result is pushed back to the GUI thread with
// QMetaObject::invokeMethod.
#pragma once

#include <QMainWindow>
#include <QVector>
#include <QThreadPool>
#include <QHash>
#include <QString>
#include <functional>

QT_BEGIN_NAMESPACE
class QListWidget;
class QStackedWidget;
class QTableWidget;
class QLabel;
class QSlider;
class QToolButton;
class QLineEdit;
class QTimer;
class QImage;
class QByteArray;
class QCloseEvent;
class QSystemTrayIcon;
QT_END_NAMESPACE

class MprisController;

// Wire models — mirror the JSON emitted by corelib (jTrack/jAlbum/jPlaylist).
struct Track {
    QString id, name, artistLine, albumName, artworkUrl;
    QString artistId;            // jTrack.artists[0].id — drives the artist view
    qint64  durationMs = 0;
};
struct Album {
    QString id, name, artistLine, artworkUrl;
};
struct Playlist {
    QString id, name, owner, artworkUrl;
    int     trackCount = 0;
};
// jArtistInfo: {id,name,artworkUrl,nbFans}.
struct ArtistInfo {
    QString id, name, artworkUrl;
    int     nbFans = 0;
};
// One timed line of synced lyrics ({timeMs,text}).
struct LyricsLine {
    qint64  timeMs = 0;
    QString text;
};
// DZLyricsJSON result: {plain, synced:[{timeMs,text}], isSynced}.
struct LyricsData {
    bool                isSynced = false;
    QString             plain;
    QVector<LyricsLine> lines;   // populated only when isSynced
};

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);

protected:
    void closeEvent(QCloseEvent *event) override;

private:
    // ---- UI construction ----
    void          buildMenu();
    void          buildSidebar();
    QWidget      *buildTracksPage();
    QWidget      *buildPlaylistsPage();
    QWidget      *buildSearchPage();
    QWidget      *buildLyricsPage();
    QWidget      *buildArtistPage();
    QWidget      *buildTransport();
    QTableWidget *makeTrackTable();
    // Right-click "Go to Artist" / "Show Lyrics" on any track table; src points
    // at the QVector backing that table's rows.
    void          installTrackMenu(QTableWidget *table, QVector<Track> *src);

    // ---- lyrics view (stack page) ----
    void openLyrics();                                   // current track (transport)
    void openLyricsFor(const QString &trackId, const QString &title);
    void loadLyrics(const QString &trackId, const QString &title);
    void renderLyrics(const QString &trackId, const QString &title,
                      const LyricsData &d);
    void updateLyricsHighlight(qint64 posMs);

    // ---- artist view (stack page) ----
    void openArtistForCurrent();                         // current track's artist
    void openArtist(const QString &artistId);
    void renderArtist(const QByteArray &json, int gen);

    // Remember the browse page to return to from a lyrics/artist detour.
    void rememberReturnPage();

    // ---- flow / browse (all heavy work on a worker thread) ----
    void startLogin();
    void onSidebarChanged(int row);
    void loadFavorites();
    void loadCharts();
    void loadPlaylists();
    void openPlaylist(const Playlist &p);
    void openAlbum(const Album &a);
    void runSearch();

    // ---- track table filling + async cover art ----
    void fillTrackTable(QTableWidget *table, const QVector<Track> &tracks, int gen);
    void fetchImage(const QString &url, int gen, std::function<void(const QImage &)> apply);

    // ---- playback ----
    void playFrom(const QVector<Track> &list, int index);
    void playCurrent();
    void togglePause();
    void next();
    void prev();
    void setVolume(int percent);
    void setNowPlaying(const Track &t);
    void tick();

    // ---- OS integration: MPRIS media controls, tray, settings ----
    void setupMpris();
    void setupTray();
    void openSettings();
    void applyAccount(const QByteArray &json);
    void applyQuality(int level);
    void applyReplayGain(bool on);
    void quitApp();
    QString settingsPath() const;

    // ---- widgets ----
    QListWidget   *m_sidebar       = nullptr;
    QStackedWidget*m_stack         = nullptr;
    QLabel        *m_tracksHeader  = nullptr;
    QTableWidget  *m_trackTable    = nullptr;
    QListWidget   *m_playlistGrid  = nullptr;
    QLineEdit     *m_searchEdit    = nullptr;
    QTableWidget  *m_searchTrackTable = nullptr;
    QListWidget   *m_searchResults = nullptr;

    // lyrics page
    QLabel        *m_lyricsTitle   = nullptr;
    QListWidget   *m_lyricsList    = nullptr;   // one item per line (synced or plain)

    // artist page
    QLabel        *m_artistName    = nullptr;
    QLabel        *m_artistFans    = nullptr;
    QLabel        *m_artistAvatar  = nullptr;
    QTableWidget  *m_artistTopTable    = nullptr;
    QListWidget   *m_artistAlbumsGrid  = nullptr;
    QListWidget   *m_artistRelatedGrid = nullptr;

    QToolButton *m_prevBtn = nullptr, *m_playBtn = nullptr, *m_nextBtn = nullptr;
    QToolButton *m_shuffleBtn = nullptr, *m_repeatBtn = nullptr;
    QSlider     *m_seek = nullptr, *m_vol = nullptr;
    QLabel      *m_nowPlaying = nullptr, *m_cover = nullptr,
                *m_posLabel = nullptr, *m_durLabel = nullptr;
    QTimer      *m_poll = nullptr;

    // ---- data ----
    QVector<Track>    m_tableTracks;    // rows currently shown in m_trackTable
    QVector<Track>    m_searchTracks;   // rows currently shown in m_searchTrackTable
    QVector<Album>    m_searchAlbums;
    QVector<Playlist> m_searchPlaylists;
    QVector<Playlist> m_playlists;

    // lyrics state
    QHash<QString, LyricsData> m_lyricsCache;       // parsed lyrics, keyed by track id
    QVector<qint64>            m_lyricsTimes;        // per-row start time (synced only)
    QString m_lyricsShownId;        // track currently rendered in the lyrics page
    QString m_lyricsRequestedId;    // most recent fetch target (guards re-fetch)
    bool    m_lyricsIsSynced = false;
    bool    m_lyricsFollowsPlayback = false; // auto-refetch when the track changes
    int     m_lyricsActiveRow = -1;          // highlighted line, or -1
    int     m_lyricsGen       = 0;           // guards async lyrics results

    // artist state
    QVector<Track>      m_artistTopTracks;
    QVector<Album>      m_artistAlbums;
    QVector<ArtistInfo> m_artistRelated;

    int m_returnPage = 0;           // stack index to restore from lyrics/artist

    QVector<Track> m_queue;             // the playing queue
    int            m_queueIndex = -1;
    Track          m_current;
    bool           m_hasCurrent = false;

    bool m_loggedIn   = false;
    bool m_seeking    = false;          // true while the user drags the seek slider
    int  m_lastFinished = 0;            // last DZFinishedCount() seen (auto-advance)
    int  m_artGen     = 0;              // bumped on every list reload to drop stale art
    int  m_playGen    = 0;              // bumped per track start; guards now-playing cover
    bool m_shuffle    = false;
    int  m_repeat     = 0;              // 0 off, 1 all, 2 one

    // ---- OS integration state ----
    MprisController *m_mpris       = nullptr;   // session-bus media controls
    QSystemTrayIcon *m_tray        = nullptr;   // background / close-to-tray
    QString          m_lastStatus;              // dedupe MPRIS PlaybackStatus
    int              m_quality     = 0;         // 0 Normal, 1 High, 2 HiFi
    bool             m_replayGain  = false;     // loudness normalization (DZReplayGain)
    bool             m_closeToTray = true;      // honour close-to-tray setting

    // ---- account tier (DZAccountJSON) ----
    QString m_accountName, m_accountOffer;      // shown in About / status bar
    bool    m_canHq       = false;              // plan allows MP3 320
    bool    m_canHifi     = false;              // plan allows FLAC
    bool    m_haveAccount = false;              // DZAccountJSON parsed OK
    bool             m_forceQuit   = false;     // set by an explicit Quit
    bool             m_trayHintShown = false;   // first hide-to-tray notice

    // Cover-art fetches run on a dedicated bounded pool so a burst of downloads
    // never starves playback/browse work on the global pool.
    QThreadPool m_artPool;
};
