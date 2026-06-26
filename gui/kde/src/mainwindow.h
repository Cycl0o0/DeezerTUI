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
QT_END_NAMESPACE

// Wire models — mirror the JSON emitted by corelib (jTrack/jAlbum/jPlaylist).
struct Track {
    QString id, name, artistLine, albumName, artworkUrl;
    qint64  durationMs = 0;
};
struct Album {
    QString id, name, artistLine, artworkUrl;
};
struct Playlist {
    QString id, name, owner, artworkUrl;
    int     trackCount = 0;
};

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);

private:
    // ---- UI construction ----
    void          buildMenu();
    void          buildSidebar();
    QWidget      *buildTracksPage();
    QWidget      *buildPlaylistsPage();
    QWidget      *buildSearchPage();
    QWidget      *buildTransport();
    QTableWidget *makeTrackTable();

    // ---- flow / browse (all heavy work on a worker thread) ----
    void startLogin();
    void onSidebarChanged(int row);
    void loadFavorites();
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

    // ---- widgets ----
    QListWidget   *m_sidebar       = nullptr;
    QStackedWidget*m_stack         = nullptr;
    QLabel        *m_tracksHeader  = nullptr;
    QTableWidget  *m_trackTable    = nullptr;
    QListWidget   *m_playlistGrid  = nullptr;
    QLineEdit     *m_searchEdit    = nullptr;
    QTableWidget  *m_searchTrackTable = nullptr;
    QListWidget   *m_searchResults = nullptr;

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

    // Cover-art fetches run on a dedicated bounded pool so a burst of downloads
    // never starves playback/browse work on the global pool.
    QThreadPool m_artPool;
};
