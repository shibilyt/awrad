package app.awrad.awrad_dhikrgoalstracker.ui.screens.createdhikr

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.data.model.AwradId
import app.awrad.awrad_dhikrgoalstracker.data.model.DhikrCategory
import app.awrad.awrad_dhikrgoalstracker.data.model.UserTag
import app.awrad.awrad_dhikrgoalstracker.data.model.toStringResId
import app.awrad.awrad_dhikrgoalstracker.domain.UserTagNormalizer
import app.awrad.awrad_dhikrgoalstracker.ui.theme.NotoNaskhArabicFontFamily
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateDhikrScreen(
    onNavigateBack: () -> Unit,
    onDhikrCreated: () -> Unit,
    viewModel: CreateDhikrViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val availableTags by viewModel.availableTags.collectAsStateWithLifecycle()
    var showOptionalDetails by rememberSaveable { mutableStateOf(false) }
    var showCategorySelector by rememberSaveable { mutableStateOf(false) }
    var showTagSelector by rememberSaveable { mutableStateOf(false) }
    var categorySearchQuery by rememberSaveable { mutableStateOf("") }
    var tagSearchQuery by rememberSaveable { mutableStateOf("") }
    val pickAudio = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument(),
    ) { uri ->
        if (uri != null) viewModel.importAudio(uri)
    }

    LaunchedEffect(uiState.isSaved, uiState.isDeleted) {
        if (uiState.isSaved || uiState.isDeleted) onDhikrCreated()
    }

    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        stringResource(
                            if (uiState.isEditing) R.string.edit_dhikr_title else R.string.create_dhikr_title,
                        ),
                    )
                },
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
        bottomBar = {
            CreateDhikrSaveBar(
                arabic = uiState.arabic,
                isSaving = uiState.isSaving,
                onSave = viewModel::save,
            )
        },
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Spacer(modifier = Modifier.height(2.dp))

            CreateDhikrComposerIntro()

            CreateDhikrEssentialFields(
                arabic = uiState.arabic,
                title = uiState.title,
                onArabicChanged = viewModel::onArabicChanged,
                onTitleChanged = viewModel::onTitleChanged,
            )

            CreateDhikrOptionalDetailsLauncher(
                selectedTagCount = uiState.selectedTagIds.size,
                hasAudio = uiState.ownedAudioName != null,
                onClick = { showOptionalDetails = true },
            )

            uiState.saveError?.let { code ->
                val message = when (code) {
                    "partial_failure" -> stringResource(R.string.create_dhikr_partial_failure)
                    "too_many_tags" -> stringResource(R.string.tag_limit_reached)
                    else -> stringResource(R.string.create_dhikr_save_failed)
                }
                Text(
                    text = message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            if (uiState.isEditing) {
                OutlinedButton(
                    onClick = viewModel::delete,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(stringResource(R.string.delete_dhikr))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))
        }
    }

    if (showOptionalDetails) {
        CreateDhikrOptionalDetailsSheet(
            uiState = uiState,
            onDismiss = { showOptionalDetails = false },
            onTransliterationChanged = viewModel::onTransliterationChanged,
            onTranslationChanged = viewModel::onTranslationChanged,
            onOpenCategorySelector = {
                categorySearchQuery = ""
                showOptionalDetails = false
                showCategorySelector = true
            },
            onOpenTagSelector = {
                tagSearchQuery = ""
                showOptionalDetails = false
                showTagSelector = true
            },
            onPickAudio = {
                pickAudio.launch(
                    arrayOf(
                        "audio/mpeg",
                        "audio/mp4",
                        "audio/aac",
                        "audio/wav",
                        "audio/x-wav",
                        "audio/*",
                    ),
                )
            },
            onRemoveAudio = viewModel::removeAudio,
            onAudioCountChanged = viewModel::onAudioCountPerPlayChanged,
        )
    }

    if (showCategorySelector) {
        CreateDhikrCategorySelectorSheet(
            selectedCategories = uiState.selectedCategories,
            categorySearchQuery = categorySearchQuery,
            onSearchQueryChanged = { categorySearchQuery = it },
            onToggleCategory = viewModel::toggleCategory,
            onDismiss = {
                showCategorySelector = false
                showOptionalDetails = true
            },
        )
    }

    if (showTagSelector) {
        CreateDhikrTagSelectorSheet(
            availableTags = availableTags,
            selectedTagIds = uiState.selectedTagIds,
            tagSearchQuery = tagSearchQuery,
            onSearchQueryChanged = { tagSearchQuery = it },
            onCreateTag = viewModel::createAndSelectTag,
            onToggleTag = viewModel::toggleTag,
            onDismiss = {
                showTagSelector = false
                showOptionalDetails = true
            },
        )
    }
}

@Composable
private fun CreateDhikrEssentialFields(
    arabic: String,
    title: String,
    onArabicChanged: (String) -> Unit,
    onTitleChanged: (String) -> Unit,
) {
    val fieldColors = OutlinedTextFieldDefaults.colors(
        unfocusedContainerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.surface
        },
        focusedContainerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.surface
        },
    )

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        OutlinedTextField(
            value = arabic,
            onValueChange = onArabicChanged,
            modifier = Modifier.fillMaxWidth(),
            label = {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(stringResource(R.string.create_dhikr_arabic_label))
                    Text(
                        text = stringResource(R.string.create_dhikr_required),
                        color = MaterialTheme.colorScheme.primary,
                    )
                }
            },
            placeholder = { Text(stringResource(R.string.create_dhikr_arabic_hint)) },
            shape = RoundedCornerShape(22.dp),
            colors = fieldColors,
            minLines = 4,
            maxLines = 9,
            textStyle = MaterialTheme.typography.headlineSmall.copy(
                fontFamily = NotoNaskhArabicFontFamily,
                textAlign = TextAlign.End,
            ),
        )

        OutlinedTextField(
            value = title,
            onValueChange = onTitleChanged,
            modifier = Modifier.fillMaxWidth(),
            label = { Text(stringResource(R.string.create_dhikr_title_label)) },
            placeholder = { Text(stringResource(R.string.create_dhikr_title_hint)) },
            singleLine = true,
            shape = RoundedCornerShape(18.dp),
            colors = fieldColors,
        )
    }
}

@Composable
private fun CreateDhikrOptionalDetailsLauncher(
    selectedTagCount: Int,
    hasAudio: Boolean,
    onClick: () -> Unit,
) {
    val summary = when {
        selectedTagCount > 0 -> stringResource(R.string.create_dhikr_tags_selected, selectedTagCount)
        hasAudio -> stringResource(R.string.create_dhikr_audio_attached)
        else -> stringResource(R.string.create_dhikr_optional_details_body)
    }

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(20.dp),
        color = MaterialTheme.colorScheme.surface,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Surface(
                modifier = Modifier.size(44.dp),
                shape = CircleShape,
                color = MaterialTheme.colorScheme.primaryContainer,
            ) {
                Icon(
                    imageVector = Icons.Filled.Add,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                    modifier = Modifier.padding(11.dp),
                )
            }
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(3.dp),
            ) {
                Text(
                    text = stringResource(R.string.create_dhikr_optional_details),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = summary,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun CreateDhikrComposerIntro() {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = stringResource(R.string.create_dhikr_composer_title),
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Text(
            text = stringResource(R.string.create_dhikr_composer_body),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun CreateDhikrSaveBar(
    arabic: String,
    isSaving: Boolean,
    onSave: () -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 10.dp,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Button(
                onClick = onSave,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(56.dp),
                enabled = arabic.isNotBlank() && !isSaving,
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(
                    text = if (isSaving) {
                        stringResource(R.string.create_dhikr_saving)
                    } else {
                        stringResource(R.string.create_dhikr_save)
                    },
                    style = MaterialTheme.typography.titleMedium,
                )
            }
            Text(
                text = stringResource(R.string.create_dhikr_private_copy),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateDhikrOptionalDetailsSheet(
    uiState: CreateDhikrUiState,
    onDismiss: () -> Unit,
    onTransliterationChanged: (String) -> Unit,
    onTranslationChanged: (String) -> Unit,
    onOpenCategorySelector: () -> Unit,
    onOpenTagSelector: () -> Unit,
    onPickAudio: () -> Unit,
    onRemoveAudio: () -> Unit,
    onAudioCountChanged: (Int) -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val fieldColors = OutlinedTextFieldDefaults.colors(
        unfocusedContainerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.surface
        },
        focusedContainerColor = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.surface
        },
    )

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    text = stringResource(R.string.create_dhikr_optional_details),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    text = stringResource(R.string.create_dhikr_optional_details_hint),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            OutlinedTextField(
                value = uiState.transliteration,
                onValueChange = onTransliterationChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_transliteration_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_transliteration_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
            )

            OutlinedTextField(
                value = uiState.translation,
                onValueChange = onTranslationChanged,
                modifier = Modifier.fillMaxWidth(),
                label = { Text(stringResource(R.string.create_dhikr_translation_label)) },
                placeholder = { Text(stringResource(R.string.create_dhikr_translation_hint)) },
                shape = RoundedCornerShape(18.dp),
                colors = fieldColors,
                minLines = 2,
            )

            OutlinedButton(
                onClick = onOpenCategorySelector,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = stringResource(R.string.create_dhikr_category_label),
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Text(
                        text = stringResource(
                            R.string.create_dhikr_categories_selected,
                            uiState.selectedCategories.size,
                        ),
                    )
                }
            }

            OutlinedButton(
                onClick = onOpenTagSelector,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = stringResource(R.string.create_dhikr_tags_label),
                        style = MaterialTheme.typography.labelMedium,
                    )
                    Text(
                        text = if (uiState.selectedTagIds.isEmpty()) {
                            stringResource(R.string.create_dhikr_tags_none)
                        } else {
                            stringResource(R.string.create_dhikr_tags_selected, uiState.selectedTagIds.size)
                        },
                    )
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(
                    text = stringResource(R.string.create_dhikr_audio_label),
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                OutlinedButton(
                    onClick = onPickAudio,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = stringResource(
                            if (uiState.ownedAudioName != null) R.string.replace_audio else R.string.import_audio,
                        ),
                    )
                }
                if (uiState.ownedAudioMissing) {
                    Text(
                        text = stringResource(R.string.audio_missing_body),
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                } else if (uiState.ownedAudioName != null) {
                    OutlinedButton(
                        onClick = onRemoveAudio,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(stringResource(R.string.remove_audio))
                    }
                }

                val canEditAudioCount = CreateDhikrEditorState.canEditAudioCount(
                    hasStagedAudio = uiState.stagedAudio != null,
                    hasPersistedOwnedAudio =
                        uiState.persistedOwnedAudioPresent && !uiState.removeOwnedAudioPending,
                )
                Text(
                    text = stringResource(R.string.create_dhikr_counts_per_play),
                    style = MaterialTheme.typography.titleSmall,
                    color = if (canEditAudioCount) {
                        MaterialTheme.colorScheme.onSurfaceVariant
                    } else {
                        MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    },
                )
                val countsCd = stringResource(R.string.cd_counts_per_play)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.semantics { contentDescription = countsCd },
                ) {
                    IconButton(
                        enabled = canEditAudioCount,
                        onClick = { onAudioCountChanged(uiState.audioCountPerPlay - 1) },
                    ) {
                        Icon(
                            Icons.Filled.Remove,
                            contentDescription = stringResource(R.string.cd_decrease_counts_per_play),
                        )
                    }
                    Text(
                        text = uiState.audioCountPerPlay.toString(),
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier.width(40.dp),
                        textAlign = TextAlign.Center,
                        color = if (canEditAudioCount) {
                            MaterialTheme.colorScheme.onSurface
                        } else {
                            MaterialTheme.colorScheme.onSurface.copy(alpha = 0.38f)
                        },
                    )
                    IconButton(
                        enabled = canEditAudioCount,
                        onClick = { onAudioCountChanged(uiState.audioCountPerPlay + 1) },
                    ) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = stringResource(R.string.cd_increase_counts_per_play),
                        )
                    }
                }
                if (!canEditAudioCount) {
                    Text(
                        text = stringResource(R.string.create_dhikr_counts_requires_audio),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                uiState.audioError?.let { reason ->
                    val message = when (reason) {
                        "SIZE" -> stringResource(R.string.custom_audio_too_large)
                        "DURATION" -> stringResource(R.string.custom_audio_too_long)
                        "CORRUPT" -> stringResource(R.string.custom_audio_corrupt)
                        "IO" -> stringResource(R.string.custom_audio_io)
                        else -> stringResource(R.string.custom_audio_unsupported)
                    }
                    Text(text = message, color = MaterialTheme.colorScheme.error)
                }
            }

            Button(
                onClick = onDismiss,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                shape = RoundedCornerShape(16.dp),
            ) {
                Text(stringResource(R.string.action_done))
            }
            Spacer(modifier = Modifier.height(20.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateDhikrCategorySelectorSheet(
    selectedCategories: List<DhikrCategory>,
    categorySearchQuery: String,
    onSearchQueryChanged: (String) -> Unit,
    onToggleCategory: (DhikrCategory) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val normalizedQuery = categorySearchQuery.trim()
    val categoryOptions = DhikrCategory.entries.map { category ->
        category to stringResource(category.toStringResId())
    }.filter { (_, label) -> normalizedQuery.isBlank() || label.contains(normalizedQuery, ignoreCase = true) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .padding(bottom = 28.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.create_dhikr_choose_categories),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            Text(
                text = stringResource(R.string.create_dhikr_categories_selected, selectedCategories.size),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            OutlinedTextField(
                value = categorySearchQuery,
                onValueChange = onSearchQueryChanged,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.create_dhikr_search_categories_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
            )
            categoryOptions.forEach { (category, label) ->
                val selected = category in selectedCategories
                CreateDhikrSelectorRow(
                    label = label,
                    selected = selected,
                    onClick = { onToggleCategory(category) },
                )
            }
            Button(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth().height(52.dp),
                shape = RoundedCornerShape(16.dp),
            ) {
                Text(stringResource(R.string.action_done))
            }
        }
    }
}

@Composable
private fun CreateDhikrSelectorRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    leadingAddIcon: Boolean = false,
) {
    Surface(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp),
        color = if (selected) {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = if (isAwradDarkTheme()) 0.5f else 0.7f)
        } else {
            MaterialTheme.colorScheme.surfaceContainerLow
        },
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (leadingAddIcon) {
                Icon(Icons.Filled.Add, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            }
            Text(
                text = label,
                style = MaterialTheme.typography.bodyLarge,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                modifier = Modifier.weight(1f),
            )
            if (selected) {
                Surface(modifier = Modifier.size(24.dp), shape = CircleShape, color = MaterialTheme.colorScheme.primary) {
                    Icon(
                        imageVector = Icons.Filled.Check,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier.padding(4.dp),
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreateDhikrTagSelectorSheet(
    availableTags: List<UserTag>,
    selectedTagIds: Set<AwradId>,
    tagSearchQuery: String,
    onSearchQueryChanged: (String) -> Unit,
    onCreateTag: (String) -> Unit,
    onToggleTag: (AwradId) -> Unit,
    onDismiss: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val normalizedQuery = tagSearchQuery.trim()
    val normalizedCandidate = UserTagNormalizer.normalize(tagSearchQuery)
    val matchingTags = availableTags.filter { tag ->
        normalizedQuery.isBlank() || tag.name.contains(normalizedQuery, ignoreCase = true)
    }
    val canCreateTag = normalizedCandidate != null && availableTags.none {
        it.normalizedName == normalizedCandidate.normalizedName
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = 20.dp, vertical = 12.dp)
                .padding(bottom = 28.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                text = stringResource(R.string.create_dhikr_tags_label),
                style = MaterialTheme.typography.titleLarge,
            )
            OutlinedTextField(
                value = tagSearchQuery,
                onValueChange = onSearchQueryChanged,
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.create_dhikr_search_or_add_tags_hint)) },
                singleLine = true,
                shape = RoundedCornerShape(18.dp),
            )
            if (canCreateTag) {
                CreateDhikrSelectorRow(
                    label = stringResource(R.string.create_dhikr_add_tag, normalizedCandidate.displayName),
                    selected = false,
                    leadingAddIcon = true,
                    onClick = { onCreateTag(tagSearchQuery) },
                )
            }
            if (matchingTags.isEmpty()) {
                Text(
                    text = if (availableTags.isEmpty()) {
                        stringResource(R.string.create_dhikr_tags_empty)
                    } else {
                        stringResource(R.string.create_dhikr_tags_no_match)
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    matchingTags.forEach { tag ->
                        val selected = tag.id in selectedTagIds
                        CreateDhikrSelectorRow(
                            label = tag.name,
                            selected = selected,
                            onClick = { onToggleTag(tag.id) },
                        )
                    }
                }
            }
        }
    }
}
