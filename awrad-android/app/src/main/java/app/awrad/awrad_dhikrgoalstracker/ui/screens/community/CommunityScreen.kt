package app.awrad.awrad_dhikrgoalstracker.ui.screens.community

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import app.awrad.awrad_dhikrgoalstracker.R
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualCard
import app.awrad.awrad_dhikrgoalstracker.ui.components.RitualPrimaryButton
import app.awrad.awrad_dhikrgoalstracker.ui.screens.auth.AuthViewModel
import app.awrad.awrad_dhikrgoalstracker.ui.theme.isAwradDarkTheme

@Composable
fun CommunityScreen(
    onNavigateToLogin: () -> Unit,
    onNavigateToSignup: () -> Unit,
    viewModel: AuthViewModel = hiltViewModel(),
) {
    val isLoggedIn by viewModel.isLoggedIn.collectAsState()
    val userEmail by viewModel.userEmail.collectAsState()
    val pendingVerificationEmail by viewModel.pendingVerificationEmail.collectAsState()
    val isEmailVerified by viewModel.isEmailVerified.collectAsState()
    val sessions by viewModel.sessions.collectAsState()
    LaunchedEffect(isLoggedIn, isEmailVerified) {
        if (isLoggedIn && isEmailVerified) viewModel.loadSessions()
    }
    val density = LocalDensity.current
    val statusBarTopPadding = with(density) { WindowInsets.statusBars.getTop(this).toDp() }

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .padding(
                top = statusBarTopPadding + 22.dp,
                bottom = 112.dp,
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = maxHeight)
                .verticalScroll(rememberScrollState()),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            CommunityHeader(
                isLoggedIn = isLoggedIn,
                onLogout = viewModel::logout,
            )

            Spacer(Modifier.height(20.dp))

            if (pendingVerificationEmail != null) {
                VerificationRequiredContent(
                    email = pendingVerificationEmail,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            } else if (isLoggedIn && isEmailVerified) {
                LoggedInContent(
                    userEmail = userEmail,
                    sessions = sessions,
                    onRevokeSession = viewModel::revokeSession,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            } else {
                GuestContent(
                    onNavigateToLogin = onNavigateToLogin,
                    onNavigateToSignup = onNavigateToSignup,
                    modifier = Modifier.padding(horizontal = 20.dp),
                )
            }
        }
    }
}

@Composable
private fun VerificationRequiredContent(email: String?, modifier: Modifier = Modifier) {
    RitualCard(modifier = modifier.fillMaxWidth(), shape = RoundedCornerShape(30.dp)) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CommunityMark()
            Spacer(Modifier.height(22.dp))
            Text(
                text = stringResource(R.string.community_verify_email_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = stringResource(R.string.community_verify_email_body, email.orEmpty()),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun CommunityHeader(
    isLoggedIn: Boolean,
    onLogout: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier.weight(1f),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(
                text = stringResource(R.string.community_title),
                style = MaterialTheme.typography.displayMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 1,
            )
            Text(
                text = stringResource(R.string.community_subtitle),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
        }
        if (isLoggedIn) {
            TextButton(
                onClick = onLogout,
                modifier = Modifier.padding(start = 12.dp),
            ) {
                Text(stringResource(R.string.auth_logout))
            }
        }
    }
}

@Composable
private fun GuestContent(
    onNavigateToLogin: () -> Unit,
    onNavigateToSignup: () -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CommunityMark()

            Spacer(Modifier.height(22.dp))

            Text(
                text = stringResource(R.string.community_join_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )

            Spacer(Modifier.height(10.dp))

            Text(
                text = stringResource(R.string.community_join_subtitle),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
            )

            Spacer(Modifier.height(28.dp))

            RitualPrimaryButton(
                text = stringResource(R.string.auth_signup),
                onClick = onNavigateToSignup,
            )

            Spacer(Modifier.height(12.dp))

            OutlinedButton(
                onClick = onNavigateToLogin,
                modifier = Modifier.fillMaxWidth().height(54.dp),
                shape = RoundedCornerShape(18.dp),
            ) {
                Text(stringResource(R.string.auth_login))
            }
        }
    }
}

@Composable
private fun LoggedInContent(
    userEmail: String?,
    sessions: List<app.awrad.awrad_dhikrgoalstracker.data.network.AuthSession>,
    onRevokeSession: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    RitualCard(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(30.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            CommunityMark()

            Spacer(Modifier.height(22.dp))

            Text(
                text = stringResource(R.string.community_coming_soon),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurface,
            )

            if (userEmail != null) {
                Spacer(Modifier.height(12.dp))
                Text(
                    text = stringResource(R.string.community_logged_in_as, userEmail),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }
            if (sessions.isNotEmpty()) {
                Spacer(Modifier.height(20.dp))
                Text(stringResource(R.string.community_active_devices), fontWeight = FontWeight.SemiBold)
                sessions.forEach { session ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(session.deviceName, modifier = Modifier.weight(1f))
                        TextButton(onClick = { onRevokeSession(session.id) }) {
                            Text(stringResource(R.string.community_revoke_device))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CommunityMark(
    modifier: Modifier = Modifier,
) {
    Surface(
        modifier = modifier.size(68.dp),
        shape = CircleShape,
        color = if (isAwradDarkTheme()) {
            MaterialTheme.colorScheme.surfaceContainerHigh
        } else {
            MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.58f)
        },
    ) {
        Box(contentAlignment = Alignment.Center) {
            Icon(
                imageVector = Icons.Rounded.Groups,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(34.dp),
            )
        }
    }
}
