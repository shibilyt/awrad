package app.awrad.awrad_dhikrgoalstracker.ui.screens.managetags

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ManageTagsScreen(
    onNavigateBack: () -> Unit,
    viewModel: ManageTagsViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color.Transparent,
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.manage_tags)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.action_back),
                        )
                    }
                },
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (uiState.dhikrTitle.isNotBlank()) {
                Text(
                    text = uiState.dhikrTitle,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                val tagNameCd = stringResource(R.string.cd_tag_name_field)
                OutlinedTextField(
                    value = uiState.newTagName,
                    onValueChange = viewModel::onNewTagNameChanged,
                    modifier = Modifier
                        .weight(1f)
                        .semantics { contentDescription = tagNameCd },
                    label = { Text(stringResource(R.string.tag_name_label)) },
                    singleLine = true,
                    shape = RoundedCornerShape(18.dp),
                )
                Button(onClick = viewModel::createTag) {
                    Text(stringResource(R.string.create_tag))
                }
            }

            uiState.errorMessage?.let { code ->
                val message = when (code) {
                    "too_many_tags" -> stringResource(R.string.tag_limit_reached)
                    else -> stringResource(R.string.tag_invalid_name)
                }
                Text(text = message, color = MaterialTheme.colorScheme.error)
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(uiState.allTags, key = { it.id }) { tag ->
                    val assigned = tag.id in uiState.assignedTagIds
                    if (uiState.renamingTagId == tag.id) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedTextField(
                                value = uiState.renameText,
                                onValueChange = viewModel::onRenameTextChanged,
                                modifier = Modifier.fillMaxWidth(),
                                singleLine = true,
                                label = { Text(stringResource(R.string.tag_name_label)) },
                            )
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                Button(onClick = viewModel::commitRename) {
                                    Text(stringResource(R.string.tag_rename_save))
                                }
                                OutlinedButton(onClick = viewModel::cancelRename) {
                                    Text(stringResource(R.string.action_cancel))
                                }
                            }
                        }
                    } else {
                        val assignedCd = if (assigned) {
                            stringResource(R.string.cd_tag_assigned, tag.name)
                        } else {
                            stringResource(R.string.cd_tag_unassigned, tag.name)
                        }
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .semantics { contentDescription = assignedCd },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Checkbox(
                                checked = assigned,
                                onCheckedChange = { viewModel.toggleAssignment(tag.id) },
                            )
                            Text(
                                text = tag.name,
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.bodyLarge,
                            )
                            TextButton(onClick = { viewModel.beginRename(tag.id) }) {
                                Text(stringResource(R.string.tag_rename))
                            }
                            TextButton(onClick = { viewModel.deleteTag(tag.id) }) {
                                Text(stringResource(R.string.tag_delete))
                            }
                        }
                    }
                }
                item { Spacer(modifier = Modifier.height(24.dp)) }
            }
        }
    }
}
