package fr.cyclooo.opendeezer.tv

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import fr.cyclooo.opendeezer.AppViewModel
import fr.cyclooo.opendeezer.engine.Album
import fr.cyclooo.opendeezer.engine.Engine
import fr.cyclooo.opendeezer.engine.HomeData
import fr.cyclooo.opendeezer.engine.Playlist
import fr.cyclooo.opendeezer.engine.SearchResults
import fr.cyclooo.opendeezer.engine.Track
import fr.cyclooo.opendeezer.ui.components.Artwork
import kotlinx.coroutines.launch

/** A pushed album/playlist detail view, shown as an overlay over the content. */
private data class TvDetailData(
    val title: String,
    val subtitle: String,
    val artworkUrl: String,
    val tracks: List<Track>,
)

@Composable
fun TvRootScreen(vm: AppViewModel) {
    var nav by remember { mutableStateOf(TvNav.Home) }
    var detail by remember { mutableStateOf<TvDetailData?>(null) }
    val player = vm.player
    val playerState by player.state.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()

    fun openAlbum(a: Album) = scope.launch {
        val tracks = Engine.albumTracks(a.id)
        if (tracks.isNotEmpty()) detail = TvDetailData(a.name, a.artistLine, a.artworkUrl, tracks)
    }
    fun openPlaylist(p: Playlist) = scope.launch {
        val tracks = Engine.playlistTracks(p.id)
        if (tracks.isNotEmpty()) detail = TvDetailData(p.name, p.owner, p.artworkUrl, tracks)
    }
    val playTracks = { list: List<Track>, i: Int -> player.playQueue(list, i) }

    Box(Modifier.fillMaxSize().background(TvPalette.screen)) {
        Row(Modifier.fillMaxSize().padding(bottom = if (playerState.current != null) 104.dp else 0.dp)) {
            TvNavRail(
                selected = nav,
                onSelect = { nav = it; detail = null },
            )
            Box(Modifier.weight(1f).fillMaxSize()) {
                when (nav) {
                    TvNav.Home -> TvBrowse(
                        onOpenSearch = { nav = TvNav.Search },
                        onPlayTracks = playTracks,
                        onOpenAlbum = { openAlbum(it) },
                        onOpenPlaylist = { openPlaylist(it) },
                    )
                    TvNav.Search -> TvSearch(
                        onPlayTracks = playTracks,
                        onOpenAlbum = { openAlbum(it) },
                        onOpenPlaylist = { openPlaylist(it) },
                    )
                    TvNav.Library -> TvLibrary(
                        onPlayTracks = playTracks,
                        onOpenPlaylist = { openPlaylist(it) },
                    )
                    TvNav.Settings -> TvSettingsScreen(account = vm.account, onLogout = { vm.logout() })
                }

                detail?.let { d ->
                    TvDetail(
                        title = d.title,
                        subtitle = d.subtitle,
                        artworkUrl = d.artworkUrl,
                        tracks = d.tracks,
                        onBack = { detail = null },
                        onPlayAll = { player.playQueue(d.tracks, 0) },
                        onPlay = { i -> player.playQueue(d.tracks, i) },
                    )
                }
            }
        }

        playerState.current?.let { cur ->
            TvNowPlayingBar(
                track = cur,
                isPlaying = playerState.isPlaying,
                onPlayPause = { player.togglePause() },
                onNext = { player.next() },
                onPrev = { player.prev() },
                modifier = Modifier.align(Alignment.BottomCenter),
            )
        }
    }
}

@Composable
private fun TvBrowse(
    onOpenSearch: () -> Unit,
    onPlayTracks: (List<Track>, Int) -> Unit,
    onOpenAlbum: (Album) -> Unit,
    onOpenPlaylist: (Playlist) -> Unit,
) {
    var home by remember { mutableStateOf<HomeData?>(null) }
    var charts by remember { mutableStateOf<SearchResults?>(null) }
    var flow by remember { mutableStateOf<List<Track>>(emptyList()) }
    val playFocus = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        home = Engine.home()
        charts = Engine.charts()
        flow = Engine.flow()
    }

    val h = home
    if (h == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = TvPalette.Purple)
        }
        return
    }

    // Give the hero its Play button initial focus once content is in.
    LaunchedEffect(h.topTracks.isNotEmpty()) {
        if (h.topTracks.isNotEmpty()) runCatching { playFocus.requestFocus() }
    }

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 40.dp, end = 40.dp, top = 40.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        h.topTracks.firstOrNull()?.let { feat ->
            item {
                TvHero(
                    title = feat.name,
                    subtitle = feat.artistLine,
                    artworkUrl = feat.artworkUrl,
                    onPlay = { onPlayTracks(h.topTracks, 0) },
                    onSearch = onOpenSearch,
                    playFocus = playFocus,
                )
            }
        }
        if (flow.isNotEmpty()) {
            item {
                TvRow("Flow · your mix", flow.take(20)) { t ->
                    TvCard(t.name, t.artistLine, t.artworkUrl, onClick = {
                        onPlayTracks(flow, flow.indexOf(t))
                    })
                }
            }
        }
        item {
            TvRow("Made for you", h.topTracks) { t ->
                TvCard(t.name, t.artistLine, t.artworkUrl, onClick = {
                    onPlayTracks(h.topTracks, h.topTracks.indexOf(t))
                })
            }
        }
        charts?.let { c ->
            item {
                TvRow("Charts", c.tracks) { t ->
                    TvCard(t.name, t.artistLine, t.artworkUrl, onClick = {
                        onPlayTracks(c.tracks, c.tracks.indexOf(t))
                    })
                }
            }
        }
        item {
            TvRow("Albums", h.topAlbums) { a ->
                TvCard(a.name, a.artistLine, a.artworkUrl, onClick = { onOpenAlbum(a) })
            }
        }
        item {
            TvRow("Playlists", h.playlists) { p ->
                TvCard(p.name, p.owner, p.artworkUrl, onClick = { onOpenPlaylist(p) })
            }
        }
    }
}

@Composable
private fun TvSearch(
    onPlayTracks: (List<Track>, Int) -> Unit,
    onOpenAlbum: (Album) -> Unit,
    onOpenPlaylist: (Playlist) -> Unit,
) {
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<SearchResults?>(null) }
    var searching by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    val runSearch = {
        val q = query.trim()
        if (q.isNotEmpty()) {
            searching = true
            scope.launch {
                results = Engine.search(q)
                searching = false
            }
        }
    }

    Column(
        Modifier.fillMaxSize().padding(48.dp),
        verticalArrangement = Arrangement.spacedBy(28.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            androidx.compose.material3.OutlinedTextField(
                value = query,
                onValueChange = { query = it },
                singleLine = true,
                label = { Text("Search tracks, albums, playlists") },
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null, tint = TvPalette.Purple) },
                modifier = Modifier.width(600.dp),
            )
            TvPill("Search", onClick = runSearch)
        }

        if (searching) {
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = TvPalette.Purple)
            }
        }
        results?.let { r ->
            LazyColumn(verticalArrangement = Arrangement.spacedBy(30.dp)) {
                item {
                    TvRow("Tracks", r.tracks) { t ->
                        TvCard(t.name, t.artistLine, t.artworkUrl, onClick = {
                            onPlayTracks(r.tracks, r.tracks.indexOf(t))
                        })
                    }
                }
                item {
                    TvRow("Albums", r.albums) { a ->
                        TvCard(a.name, a.artistLine, a.artworkUrl, onClick = { onOpenAlbum(a) })
                    }
                }
                item {
                    TvRow("Playlists", r.playlists) { p ->
                        TvCard(p.name, p.owner, p.artworkUrl, onClick = { onOpenPlaylist(p) })
                    }
                }
            }
        }
    }
}

@Composable
private fun TvLibrary(
    onPlayTracks: (List<Track>, Int) -> Unit,
    onOpenPlaylist: (Playlist) -> Unit,
) {
    var liked by remember { mutableStateOf<List<Track>?>(null) }
    var playlists by remember { mutableStateOf<List<Playlist>>(emptyList()) }

    LaunchedEffect(Unit) {
        liked = Engine.favorites()
        playlists = Engine.playlists()
    }

    if (liked == null) {
        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            CircularProgressIndicator(color = TvPalette.Purple)
        }
        return
    }
    val likedList = liked!!

    LazyColumn(
        Modifier.fillMaxSize(),
        contentPadding = PaddingValues(start = 40.dp, end = 40.dp, top = 40.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(34.dp),
    ) {
        item {
            Text(
                "Your Library",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Black,
                color = Color.White,
            )
        }
        item {
            TvRow("Liked songs", likedList) { t ->
                TvCard(t.name, t.artistLine, t.artworkUrl, onClick = {
                    onPlayTracks(likedList, likedList.indexOf(t))
                })
            }
        }
        item {
            TvRow("Your playlists", playlists) { p ->
                TvCard(p.name, p.owner, p.artworkUrl, onClick = { onOpenPlaylist(p) })
            }
        }
        if (likedList.isEmpty() && playlists.isEmpty()) {
            item {
                Text("Nothing saved yet.", color = TvPalette.TextDim, style = MaterialTheme.typography.titleMedium)
            }
        }
    }
}

@Composable
private fun TvDetail(
    title: String,
    subtitle: String,
    artworkUrl: String,
    tracks: List<Track>,
    onBack: () -> Unit,
    onPlayAll: () -> Unit,
    onPlay: (Int) -> Unit,
) {
    val playFocus = remember { FocusRequester() }
    LaunchedEffect(Unit) { runCatching { playFocus.requestFocus() } }

    Column(
        Modifier.fillMaxSize().background(TvPalette.screen).padding(48.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(24.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(180.dp).clip(RoundedCornerShape(16.dp))) {
                Artwork(artworkUrl, Modifier.fillMaxSize(), corner = 16)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    title,
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
                if (subtitle.isNotBlank()) {
                    Text(subtitle, style = MaterialTheme.typography.titleMedium, color = TvPalette.TextDim)
                }
                Text("${tracks.size} tracks", style = MaterialTheme.typography.bodyMedium, color = TvPalette.TextDim)
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    TvPill("▶  Play all", onClick = onPlayAll, focusRequester = playFocus)
                    TvPill("Back", onClick = onBack)
                }
            }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            items(tracks) { t ->
                TvTrackRow(t, onClick = { onPlay(tracks.indexOf(t)) })
            }
        }
    }
}

@Composable
private fun TvTrackRow(track: Track, onClick: () -> Unit) {
    var focused by remember { mutableStateOf(false) }
    val bg = if (focused) TvPalette.Purple.copy(alpha = 0.18f) else Color.Transparent
    Row(
        Modifier
            .fillMaxWidth()
            .onFocusChanged { focused = it.isFocused }
            .clickable(onClick = onClick)
            .clip(RoundedCornerShape(10.dp))
            .background(bg)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(Modifier.size(48.dp).clip(RoundedCornerShape(8.dp))) {
            Artwork(track.artworkUrl, Modifier.fillMaxSize(), corner = 8)
        }
        Column(Modifier.weight(1f)) {
            Text(
                track.name,
                style = MaterialTheme.typography.bodyLarge,
                color = if (focused) Color.White else TvPalette.TextDim,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                track.artistLine,
                style = MaterialTheme.typography.bodySmall,
                color = TvPalette.TextDim,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (focused) Icon(Icons.Filled.PlayArrow, contentDescription = "Play", tint = TvPalette.Purple)
    }
}

@Composable
private fun TvNowPlayingBar(
    track: Track,
    isPlaying: Boolean,
    onPlayPause: () -> Unit,
    onNext: () -> Unit,
    onPrev: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier
            .fillMaxWidth()
            .height(96.dp)
            .clip(RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp))
            .background(TvPalette.CardIdle)
            .padding(horizontal = 48.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Box(Modifier.size(60.dp).clip(RoundedCornerShape(10.dp))) {
            Artwork(track.artworkUrl, Modifier.fillMaxSize(), corner = 10)
        }
        Column(Modifier.weight(1f)) {
            Text(
                track.name,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                track.artistLine,
                style = MaterialTheme.typography.bodyMedium,
                color = TvPalette.TextDim,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        TvPill("◀◀", onClick = onPrev)
        TvPill(if (isPlaying) "❚❚" else "▶", onClick = onPlayPause)
        TvPill("▶▶", onClick = onNext)
    }
}
