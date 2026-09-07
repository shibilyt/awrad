package app.awrad.awrad_dhikrgoalstracker.ui.screens.onboarding

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CloudDone
import androidx.compose.material.icons.outlined.MailOutline
import androidx.compose.material.icons.outlined.Translate
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

// ─── Language Scene ──────────────────────────────────────────────────────────

/**
 * No auth backend for Google exists yet; flip this on once it does. The scene
 * lays out correctly with or without the Google button.
 */
internal const val SHOW_GOOGLE_SIGN_IN = false

private data class LanguageOption(
    val tag: String,
    val nativeNameRes: Int,
    val scriptSample: String,
)

private val languageOptions = listOf(
    LanguageOption(tag = "en", nativeNameRes = R.string.lang_english, scriptSample = "Aa"),
    LanguageOption(tag = "ar", nativeNameRes = R.string.lang_arabic, scriptSample = "أ ب"),
    LanguageOption(tag = "ml", nativeNameRes = R.string.lang_malayalam, scriptSample = "അ"),
)

@Composable
internal fun LanguageScene(
    selectedTag: String,
    onLanguageSelected: (String) -> Unit,
) {
    OnboardingScene(
        icon = {
            Box(
                modifier = Modifier
                    .size(96.dp)
                    .clip(CircleShape)
                    .background(greenContainerColor()),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.Translate,
                    contentDescription = null,
                    modifier = Modifier.size(42.dp),
                    tint = onGreenContainerColor(),
                )
            }
        },
        title = stringResource(R.string.onboarding_language_title),
        subtitle = stringResource(R.string.onboarding_language_subtitle),
        topSpacerHeight = 48.dp,
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            languageOptions.forEach { option ->
                LanguageOptionCard(
                    option = option,
                    selected = option.tag == selectedTag,
                    onClick = { onLanguageSelected(option.tag) },
                )
            }
        }
    }
}

@Composable
private fun LanguageOptionCard(
    option: LanguageOption,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val borderColor by animateColorAsState(
        targetValue = if (selected) greenAccent() else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.36f),
        animationSpec = tween(180),
        label = "languageBorder",
    )
    val scale by animateFloatAsState(
        targetValue = if (selected) 1f else 0.98f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "languageScale",
    )

    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { scaleX = scale; scaleY = scale },
        shape = RoundedCornerShape(22.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        border = BorderStroke(if (selected) 2.dp else 1.dp, borderColor),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(greenContainerColor()),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = option.scriptSample,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = onGreenContainerColor(),
                )
            }

            Spacer(modifier = Modifier.width(14.dp))

            Text(
                text = stringResource(option.nativeNameRes),
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal,
                color = MaterialTheme.colorScheme.onSurface,
            )

            OnboardingSelectionDot(selected = selected)
        }
    }
}

// ─── Account Scene ───────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun AccountScene(
    isSignedIn: Boolean,
    signedInEmail: String?,
    showAuthSheet: Boolean,
    authMode: AuthSheetMode,
    authEmail: String,
    authPassword: String,
    isAuthenticating: Boolean,
    authError: String?,
    onContinueWithEmail: () -> Unit,
    onContinueAsGuest: () -> Unit,
    onContinueSignedIn: () -> Unit,
    onDismissAuthSheet: () -> Unit,
    onAuthModeChanged: (AuthSheetMode) -> Unit,
    onAuthEmailChanged: (String) -> Unit,
    onAuthPasswordChanged: (String) -> Unit,
    onAuthSubmit: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 28.dp, vertical = 24.dp),
    ) {
        Spacer(modifier = Modifier.height(64.dp))

        AnimatedEntry(delayMillis = 0) {
            Text(
                text = stringResource(R.string.onboarding_account_eyebrow),
                style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 2.4.sp),
                fontWeight = FontWeight.SemiBold,
                color = greenAccent(),
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        AnimatedEntry(delayMillis = 110) {
            Text(
                text = stringResource(R.string.onboarding_account_title),
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        AnimatedEntry(delayMillis = 220) {
            Text(
                text = stringResource(R.string.onboarding_account_subtitle),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(modifier = Modifier.height(36.dp))

        if (isSignedIn) {
            AnimatedEntry(delayMillis = 330) {
                SignedInCard(email = signedInEmail)
            }

            Spacer(modifier = Modifier.height(20.dp))

            AnimatedEntry(delayMillis = 440) {
                AccountPrimaryButton(
                    text = stringResource(R.string.onboarding_next),
                    onClick = onContinueSignedIn,
                )
            }
        } else {
            if (SHOW_GOOGLE_SIGN_IN) {
                AnimatedEntry(delayMillis = 330) {
                    AccountChoiceButton(
                        label = stringResource(R.string.onboarding_account_google),
                        leading = {
                            Box(
                                modifier = Modifier
                                    .size(30.dp)
                                    .clip(CircleShape)
                                    .background(MaterialTheme.colorScheme.surfaceContainerHighest),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(
                                    text = "G",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                            }
                        },
                        container = if (isAwradDarkTheme()) {
                            MaterialTheme.colorScheme.surfaceContainerHigh
                        } else {
                            Color.White
                        },
                        onClick = { /* Wire to Google auth once a backend exists. */ },
                    )
                }

                Spacer(modifier = Modifier.height(14.dp))
            }

            AnimatedEntry(delayMillis = if (SHOW_GOOGLE_SIGN_IN) 440 else 330) {
                AccountChoiceButton(
                    label = stringResource(R.string.onboarding_account_email),
                    leading = {
                        Icon(
                            imageVector = Icons.Outlined.MailOutline,
                            contentDescription = null,
                            modifier = Modifier.size(22.dp),
                            tint = onGreenContainerColor(),
                        )
                    },
                    container = greenContainerColor(),
                    contentColor = onGreenContainerColor(),
                    onClick = onContinueWithEmail,
                )
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        if (!isSignedIn) {
            AnimatedEntry(delayMillis = 520) {
                Box(
                    modifier = Modifier.fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    TextButton(onClick = onContinueAsGuest) {
                        Text(
                            text = stringResource(R.string.onboarding_account_guest),
                            style = MaterialTheme.typography.titleSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = greenAccent(),
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(8.dp))
    }

    if (showAuthSheet) {
        EmailAuthSheet(
            mode = authMode,
            email = authEmail,
            password = authPassword,
            isAuthenticating = isAuthenticating,
            error = authError,
            onDismiss = onDismissAuthSheet,
            onModeChanged = onAuthModeChanged,
            onEmailChanged = onAuthEmailChanged,
            onPasswordChanged = onAuthPasswordChanged,
            onSubmit = onAuthSubmit,
        )
    }
}

@Composable
private fun SignedInCard(email: String?) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(24.dp),
        color = greenContainerColor(),
        border = BorderStroke(1.dp, greenAccent().copy(alpha = 0.28f)),
    ) {
        Row(
            modifier = Modifier.padding(18.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(greenAccent()),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Outlined.CloudDone,
                    contentDescription = null,
                    modifier = Modifier.size(22.dp),
                    tint = MaterialTheme.colorScheme.onPrimary,
                )
            }
            Spacer(modifier = Modifier.width(14.dp))
            Column {
                Text(
                    text = stringResource(R.string.onboarding_account_signed_in_title),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = onGreenContainerColor(),
                )
                if (!email.isNullOrBlank()) {
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = email,
                        style = MaterialTheme.typography.bodyMedium,
                        color = onGreenContainerColor().copy(alpha = 0.8f),
                    )
                }
            }
        }
    }
}

@Composable
private fun AccountChoiceButton(
    label: String,
    leading: @Composable () -> Unit,
    container: Color,
    onClick: () -> Unit,
    contentColor: Color = MaterialTheme.colorScheme.onSurface,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp),
        shape = RoundedCornerShape(29.dp),
        color = container,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.fillMaxSize(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            leading()
            Spacer(modifier = Modifier.width(12.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = contentColor,
            )
        }
    }
}

@Composable
private fun AccountPrimaryButton(
    text: String,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(22.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = greenAccent(),
            contentColor = MaterialTheme.colorScheme.onPrimary,
        ),
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )
    }
}

// ─── Email auth sheet ────────────────────────────────────────────────────────

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EmailAuthSheet(
    mode: AuthSheetMode,
    email: String,
    password: String,
    isAuthenticating: Boolean,
    error: String?,
    onDismiss: () -> Unit,
    onModeChanged: (AuthSheetMode) -> Unit,
    onEmailChanged: (String) -> Unit,
    onPasswordChanged: (String) -> Unit,
    onSubmit: () -> Unit,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val focusManager = LocalFocusManager.current
    var passwordVisible by remember { mutableStateOf(false) }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = MaterialTheme.colorScheme.surface,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 28.dp),
        ) {
            Text(
                text = stringResource(
                    if (mode == AuthSheetMode.SignIn) {
                        R.string.onboarding_auth_sign_in_title
                    } else {
                        R.string.onboarding_auth_create_title
                    },
                ),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = stringResource(R.string.onboarding_auth_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            Spacer(modifier = Modifier.height(20.dp))

            OutlinedTextField(
                value = email,
                onValueChange = onEmailChanged,
                label = { Text(stringResource(R.string.onboarding_auth_email_hint)) },
                singleLine = true,
                enabled = !isAuthenticating,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Email,
                    imeAction = ImeAction.Next,
                ),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
            )

            Spacer(modifier = Modifier.height(12.dp))

            OutlinedTextField(
                value = password,
                onValueChange = onPasswordChanged,
                label = { Text(stringResource(R.string.onboarding_auth_password_hint)) },
                singleLine = true,
                enabled = !isAuthenticating,
                visualTransformation = if (passwordVisible) {
                    VisualTransformation.None
                } else {
                    PasswordVisualTransformation()
                },
                trailingIcon = {
                    IconButton(onClick = { passwordVisible = !passwordVisible }) {
                        Icon(
                            imageVector = if (passwordVisible) {
                                Icons.Rounded.VisibilityOff
                            } else {
                                Icons.Rounded.Visibility
                            },
                            contentDescription = stringResource(R.string.onboarding_auth_toggle_password),
                        )
                    }
                },
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Password,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(onDone = {
                    focusManager.clearFocus()
                    onSubmit()
                }),
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(18.dp),
            )

            AnimatedVisibility(
                visible = error != null,
                enter = fadeIn(tween(200)) + slideInVertically(tween(200)) { -it / 4 },
            ) {
                Text(
                    text = when (error) {
                        null -> ""
                        AUTH_ERROR_FIELDS -> stringResource(R.string.onboarding_auth_error_fields)
                        AUTH_ERROR_PASSWORD_SETUP -> stringResource(R.string.onboarding_auth_password_setup_required)
                        else -> error
                    },
                    modifier = Modifier.padding(top = 10.dp),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

            Spacer(modifier = Modifier.height(20.dp))

            Button(
                onClick = {
                    focusManager.clearFocus()
                    onSubmit()
                },
                enabled = !isAuthenticating,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(20.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = greenAccent(),
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            ) {
                if (isAuthenticating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(20.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Text(
                        text = stringResource(
                            if (mode == AuthSheetMode.SignIn) {
                                R.string.onboarding_auth_sign_in_action
                            } else {
                                R.string.onboarding_auth_create_action
                            },
                        ),
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
            }

            Spacer(modifier = Modifier.height(6.dp))

            Box(
                modifier = Modifier.fillMaxWidth(),
                contentAlignment = Alignment.Center,
            ) {
                TextButton(
                    onClick = {
                        onModeChanged(
                            if (mode == AuthSheetMode.SignIn) {
                                AuthSheetMode.CreateAccount
                            } else {
                                AuthSheetMode.SignIn
                            },
                        )
                    },
                    enabled = !isAuthenticating,
                ) {
                    Text(
                        text = stringResource(
                            if (mode == AuthSheetMode.SignIn) {
                                R.string.onboarding_auth_switch_to_create
                            } else {
                                R.string.onboarding_auth_switch_to_sign_in
                            },
                        ),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                    )
                }
            }
        }
    }
}
