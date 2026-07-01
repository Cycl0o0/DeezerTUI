package fr.cyclooo.opendeezer.tv

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.expandHorizontally
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkHorizontally
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.LibraryMusic
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/** The destinations shown in the left rail. */
enum class TvNav(val label: String, val icon: ImageVector) {
    Home("Home", Icons.Filled.Home),
    Search("Search", Icons.Filled.Search),
    Library("Library", Icons.Filled.LibraryMusic),
    Settings("Settings", Icons.Filled.Settings),
}

/**
 * A YouTube-TV / Netflix-style left navigation rail: a slim icon strip that
 * expands to reveal labels while any of its items holds D-pad focus, then
 * collapses when focus moves back into the content.
 */
@Composable
fun TvNavRail(
    selected: TvNav,
    onSelect: (TvNav) -> Unit,
    modifier: Modifier = Modifier,
) {
    var expanded by remember { mutableStateOf(false) }
    val width by animateDpAsState(if (expanded) 220.dp else 84.dp, label = "railWidth")

    Column(
        modifier
            .fillMaxHeight()
            .width(width)
            .background(Color.Black.copy(alpha = 0.35f))
            .padding(vertical = 28.dp, horizontal = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        TvNav.entries.forEach { item ->
            TvNavItem(
                item = item,
                selected = item == selected,
                expanded = expanded,
                onFocused = { expanded = true },
                onClick = { onSelect(item) },
            )
        }
    }
}

@Composable
private fun TvNavItem(
    item: TvNav,
    selected: Boolean,
    expanded: Boolean,
    onFocused: () -> Unit,
    onClick: () -> Unit,
) {
    var focused by remember { mutableStateOf(false) }
    val bg = when {
        focused -> TvPalette.Purple
        selected -> TvPalette.Purple.copy(alpha = 0.22f)
        else -> Color.Transparent
    }
    val fg = if (focused) Color.White else if (selected) TvPalette.Purple else TvPalette.TextDim

    Row(
        Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(bg)
            .onFocusChanged {
                focused = it.isFocused
                if (it.isFocused) onFocused()
            }
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(item.icon, contentDescription = item.label, tint = fg, modifier = Modifier.size(28.dp))
        AnimatedVisibility(
            visible = expanded,
            enter = fadeIn() + expandHorizontally(),
            exit = fadeOut() + shrinkHorizontally(),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Spacer(Modifier.width(14.dp))
                Text(
                    item.label,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = if (selected || focused) FontWeight.Bold else FontWeight.Normal,
                    color = fg,
                    maxLines = 1,
                )
            }
        }
    }
}
