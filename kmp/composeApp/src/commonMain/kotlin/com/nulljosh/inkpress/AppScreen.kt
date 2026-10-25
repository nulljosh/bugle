package com.nulljosh.inkpress

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun BugleTheme(content: @Composable () -> Unit) =
    MaterialTheme(colorScheme = lightColorScheme(), content = content)

// ponytail: no add/remove-feed UI (SEED_FEEDS only) and no on-disk cache
// (JournalFeedService.saveCache/loadCache not ported) -- fetch is live every
// launch. Parsing itself is real, not a stub.
@Composable
fun AppScreen(client: FeedClient = FeedClient()) {
    var entries by remember { mutableStateOf<List<Pair<Feed, JournalEntry>>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        entries = client.refresh()
        loading = false
    }

    Surface {
        Column(Modifier.fillMaxSize().padding(24.dp)) {
            Text("Bugle", style = MaterialTheme.typography.headlineMedium)
            when {
                loading -> CircularProgressIndicator(Modifier.padding(top = 24.dp))
                entries.isEmpty() -> Text("Couldn't load feeds.", modifier = Modifier.padding(top = 24.dp))
                else -> LazyColumn(
                    modifier = Modifier.padding(top = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(entries) { (feed, entry) ->
                        Column {
                            Text(entry.title, style = MaterialTheme.typography.titleMedium)
                            Text(feed.title)
                        }
                    }
                }
            }
        }
    }
}
