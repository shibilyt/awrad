# DhikrGoal - Premium Dhikr Tracking App Implementation Plan

## **Overview**

A premium dhikr goal tracking app using top-tier Android patterns from PixelPlayer. Features audio-based counting, goal tracking, and Material You design.

**Core Features:**
- Multiple dhikr items with audio recitation
- Goal setting (e.g., 1000 repetitions)
- Audio-based counting with loop detection
- Progress tracking and analytics
- Material You theming

---

## **1. Architecture & Project Structure**

### **App Package Structure**
```
com.theveloper.dhikrgoal/
├── data/
│   ├── database/           # Room entities, DAOs, migrations
│   ├── model/             # Domain models (Dhikr, Goal, Session, etc.)
│   ├── network/           # API services (if needed for audio content)
│   ├── preferences/       # DataStore preferences
│   ├── repository/        # Data repositories
│   ├── service/           # AudioService, CountingService
│   └── worker/            # WorkManager for goal reminders/sync
├── di/                    # Hilt dependency injection modules
├── presentation/
│   ├── components/        # Reusable Compose components
│   ├── navigation/        # Navigation graph
│   ├── screens/           # Screen composables
│   └── viewmodel/         # ViewModels
├── ui/
│   ├── theme/             # Colors, typography, theming
│   └── widgets/           # Home screen widgets
└── utils/                 # Extensions and utilities
```

### **Core Architecture Patterns**
- **MVVM with Repository Pattern**: Clean separation like PixelPlayer
- **Flow-based State Management**: StateFlow/SharedFlow for reactive UI
- **Hilt Dependency Injection**: Comprehensive DI setup
- **Room Database**: Local persistence with proper migrations

---

## **2. Data Models & Database Schema**

### **Core Domain Models**
```kotlin
// Dhikr entity with audio support
data class Dhikr(
    val id: String,
    val title: String,
    val arabicText: String,
    val translation: String,
    val description: String,
    val audioFilePath: String?,
    val audioDuration: Long?,
    val category: DhikrCategory,
    val isBuiltIn: Boolean,
    val createdAt: Long
)

// Goal tracking entity
data class DhikrGoal(
    val id: String,
    val dhikrId: String,
    val targetCount: Int,
    val currentCount: Int,
    val startDate: Long,
    val targetDate: Long?,
    val isActive: Boolean,
    val countingMode: CountingMode // MANUAL, AUDIO, BOTH
)

// Session tracking for detailed analytics
data class DhikrSession(
    val id: String,
    val goalId: String,
    val startTime: Long,
    val endTime: Long?,
    val countCompleted: Int,
    val sessionType: SessionType // MANUAL, AUDIO
)
```

### **Room Database Schema**
```kotlin
@Database(
    entities = [
        DhikrEntity::class,
        DhikrGoalEntity::class,
        DhikrSessionEntity::class,
        DailyProgressEntity::class
    ],
    version = 1
)
abstract class DhikrGoalDatabase : RoomDatabase() {
    abstract fun dhikrDao(): DhikrDao
    abstract fun goalDao(): DhikrGoalDao
    abstract fun sessionDao(): DhikrSessionDao
    abstract fun progressDao(): DailyProgressDao
}
```

---

## **3. Audio Playback System with Counting**

### **Core Audio Architecture**
```kotlin
// Audio playback service inspired by PixelPlayer's MusicService
class DhikrAudioService : Service() {
    private val exoPlayer: ExoPlayer by lazy { 
        ExoPlayer.Builder(this).build() 
    }
    
    // Counting logic integrated with playback
    private val countingController: DhikrCountingController by lazy {
        DhikrCountingController(exoPlayer, repository)
    }
}

// Counting controller that syncs with audio loops
class DhikrCountingController(
    private val player: ExoPlayer,
    private val goalRepository: DhikrGoalRepository
) {
    private val _countFlow = MutableStateFlow(0)
    val countFlow: StateFlow<Int> = _countFlow.asStateFlow()
    
    // Listen for media item transitions (loop completion)
    init {
        player.addListener(object : Player.Listener {
            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                incrementCount()
            }
        })
    }
    
    private fun incrementCount() {
        viewModelScope.launch {
            val newCount = _countFlow.value + 1
            _countFlow.value = newCount
            goalRepository.updateProgress(goalId, newCount)
        }
    }
}
```

### **Audio Loop Management**
```kotlin
// Media item with loop configuration
fun createLoopingMediaItem(audioFile: String, repeatCount: Int): MediaItem {
    return MediaItem.Builder()
        .setUri(audioFile)
        .setMediaMetadata(
            MediaMetadata.Builder()
                .setCustomData(
                    MediaMetadata.KEY_LOOP_COUNT, 
                    repeatCount
                ).build()
        ).build()
}

// Player configuration for seamless looping
private fun setupPlayerForLooping() {
    exoPlayer.apply {
        repeatMode = Player.REPEAT_MODE_ONE // Loop single audio
        playWhenReady = false
        volume = 1.0f
    }
}
```

---

## **4. UI/UX Design with Modern Android Patterns**

### **Material You & Dynamic Theming**
```kotlin
// Spiritual-themed color palette with dynamic theming
val DhikrGreenPrimary = Color(0xFF2E7D32)
val DhikrGoldSecondary = Color(0xFFFFB300)
val DhikrDarkBackground = Color(0xFF1A1A2E)

// Dynamic color extraction from dhikr cards
@Composable
fun DhikrTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Color = DhikrGreenPrimary,
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) {
        dynamicDarkColorScheme(LocalContext.current).copy(
            primary = dynamicColor,
            background = DhikrDarkBackground
        )
    } else {
        dynamicLightColorScheme(LocalContext.current).copy(
            primary = dynamicColor
        )
    }
    
    MaterialTheme(colorScheme = colorScheme, content = content)
}
```

### **Key Compose Screens**
```kotlin
// Main dashboard with goal progress
@Composable
fun DhikrDashboard(
    goals: List<DhikrGoal>,
    onGoalClick: (String) -> Unit,
    onAudioStart: (String) -> Unit
) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(minSize = 160.dp),
        contentPadding = PaddingValues(16.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(goals) { goal ->
            DhikrGoalCard(
                goal = goal,
                onClick = { onGoalClick(goal.id) },
                onAudioStart = { onAudioStart(goal.id) }
            )
        }
    }
}

// Premium goal card with progress visualization
@Composable
fun DhikrGoalCard(
    goal: DhikrGoal,
    onClick: () -> Unit,
    onAudioStart: () -> Unit
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .aspectRatio(1f)
            .combinedClickable(
                onClick = onClick,
                onLongClick = { /* Show options */ }
            ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            // Circular progress indicator
            Box(contentAlignment = Alignment.Center) {
                CircularProgressIndicator(
                    progress = goal.currentCount.toFloat() / goal.targetCount,
                    modifier = Modifier.size(80.dp),
                    strokeWidth = 8.dp,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "${goal.currentCount}/${goal.targetCount}",
                    style = MaterialTheme.typography.titleMedium
                )
            }
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Text(
                text = goal.title,
                style = MaterialTheme.typography.titleSmall,
                textAlign = TextAlign.Center,
                maxLines = 2
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            // Audio play button
            IconButton(
                onClick = onAudioStart,
                modifier = Modifier
                    .background(
                        MaterialTheme.colorScheme.primary.copy(alpha = 0.1f),
                        CircleShape
                    )
            ) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = "Play with counting"
                )
            }
        }
    }
}
```

### **Navigation Architecture**
```kotlin
// Navigation graph using Compose Navigation
@Composable
fun DhikrNavigation(
    navController: NavHostController = rememberNavController()
) {
    NavHost(
        navController = navController,
        startDestination = "dashboard"
    ) {
        composable("dashboard") {
            DhikrDashboardScreen(
                onNavigateToGoal = { goalId ->
                    navController.navigate("goal/$goalId")
                }
            )
        }
        
        composable("goal/{goalId}") { backStackEntry ->
            val goalId = backStackEntry.arguments?.getString("goalId") ?: return@composable
            DhikrGoalDetailScreen(
                goalId = goalId,
                onNavigateBack = { navController.popBackStack() }
            )
        }
        
        composable("settings") {
            DhikrSettingsScreen(
                onNavigateBack = { navController.popBackStack() }
            )
        }
    }
}
```

---

## **5. Performance Optimization Strategies**

### **Baseline Profiles for Fast Startup**
```kotlin
// Baseline profile generator for dhikr flows
@LargeTest
class DhikrBaselineProfileGenerator {
    
    @Test
    fun generate() {
        rule.collect(packageName = "com.theveloper.dhikrgoal") {
            // Critical user journeys
            setupApp()
            navigateToDashboard()
            startAudioCounting()
            viewGoalProgress()
            navigateToSettings()
        }
    }
    
    private fun MacrobenchmarkScope.startAudioCounting() {
        // Find and click first goal card
        val goalCard = device.findObject(By.text("Subhanallah"))
        goalCard?.click()
        Thread.sleep(2000)
        
        // Start audio counting
        val playButton = device.findObject(By.desc("Play with counting"))
        playButton?.click()
        Thread.sleep(3000) // Let audio start and count first iteration
        
        device.pressBack()
    }
}
```

### **Compose Performance Configuration**
```kotlin
// app/compose_stability.conf
// Stabilize core data classes for optimal recomposition
com.theveloper.dhikrgoal.data.model.Dhikr
com.theveloper.dhikrgoal.data.model.DhikrGoal
com.theveloper.dhikrgoal.data.model.DhikrSession
com.theveloper.dhikrgoal.presentation.viewmodel.DhikrUiState
com.theveloper.dhikrgoal.presentation.viewmodel.CountingState

// build.gradle.kts Compose compiler settings
kotlinOptions {
    freeCompilerArgs += listOf(
        "-P",
        "plugin:androidx.compose.compiler.plugins.kotlin:stabilityConfigurationPath=${project.rootDir.absolutePath}/app/compose_stability.conf"
    )
}
```

### **Memory & Audio Optimizations**
```kotlin
// AppModule.kt - Optimized ExoPlayer setup
@Provides
@Singleton
fun provideExoPlayer(@ApplicationContext context: Context): ExoPlayer {
    return ExoPlayer.Builder(context)
        .setLoadControl(
            DefaultLoadControl.Builder()
                .setBufferDurationsMs(
                    DefaultLoadControl.DEFAULT_MIN_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_MAX_BUFFER_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS,
                    DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
                )
                .build()
        )
        .build()
}

// Efficient image caching for dhikr cards
@Provides
@Singleton
fun provideImageLoader(@ApplicationContext context: Context): ImageLoader {
    return ImageLoader.Builder(context)
        .memoryCache {
            MemoryCache.Builder(context)
                .maxSizePercent(0.15) // Optimized for simple app
                .build()
        }
        .diskCache {
            DiskCache.Builder()
                .directory(context.cacheDir.resolve("dhikr_cache"))
                .maxSizeBytes(50L * 1024 * 1024) // 50MB - smaller than PixelPlayer
                .build()
        }
        .build()
}
```

---

## **6. Implementation Roadmap**

### **Phase 1: Core Foundation (Weeks 1-2)**
**MVP Features**
- Project setup with Hilt, Room, Compose
- Basic dhikr data models and database
- Simple dashboard with manual counting
- Basic audio playback (no counting yet)
- Material You theming

**Key Deliverables**
```kotlin
// Core ViewModels
class DhikrDashboardViewModel @Inject constructor(
    private val goalRepository: DhikrGoalRepository
) : ViewModel() {
    val goals: StateFlow<List<DhikrGoal>> = goalRepository.getAllGoals()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
}

// Basic data entities
@Entity(tableName = "dhikr_goals")
data class DhikrGoalEntity(
    @PrimaryKey val id: String,
    val title: String,
    val targetCount: Int,
    val currentCount: Int
)
```

### **Phase 2: Audio Counting System (Weeks 3-4)**
**Advanced Features**
- Media3 ExoPlayer integration
- Audio loop detection and counting
- DhikrAudioService with notification
- Real-time count synchronization
- Goal progress visualization

**Technical Implementation**
```kotlin
// Enhanced audio service with counting
class DhikrAudioService : Service() {
    private lateinit var countingController: DhikrCountingController
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_COUNTING -> startCounting(intent.getStringExtra(EXTRA_DHIKR_ID))
            ACTION_STOP_COUNTING -> stopCounting()
            ACTION_PAUSE_COUNTING -> pauseCounting()
        }
        return START_STICKY
    }
}
```

### **Phase 3: Premium Features (Weeks 5-6)**
**Enhanced UX**
- Custom dhikr creation with audio upload
- Advanced statistics and analytics
- Goal reminders with WorkManager
- Home screen widgets with Glance
- Export/import functionality

### **Phase 4: Polish & Optimization (Weeks 7-8)**
**Production Ready**
- Baseline profile generation
- Comprehensive testing
- Performance optimization
- Accessibility features
- App store preparation

---

## **Tech Stack Implementation**

### **Dependencies (build.gradle.kts)**
```kotlin
dependencies {
    // Core Android
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    
    // Compose BOM
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.ui)
    implementation(libs.androidx.ui.tooling.preview)
    implementation(libs.androidx.material3)
    
    // Architecture
    implementation(libs.hilt.android)
    ksp(libs.hilt.android.compiler)
    implementation(libs.androidx.hilt.navigation.compose)
    
    // Database
    implementation(libs.androidx.room.runtime)
    ksp(libs.androidx.room.compiler)
    implementation(libs.androidx.room.ktx)
    
    // Media3 for Audio
    implementation(libs.androidx.media3.exoplayer)
    implementation(libs.androidx.media3.session)
    
    // Navigation
    implementation(libs.androidx.navigation.compose)
    
    // Image Loading
    implementation(libs.coil.compose)
    
    // Widgets
    implementation(libs.androidx.glance)
    implementation(libs.androidx.glance.appwidget)
    
    // Performance
    implementation(libs.androidx.profileinstaller)
}
```

### **Key Implementation Patterns**

#### **Dependency Injection Module**
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object DhikrAppModule {
    
    @Provides
    @Singleton
    fun provideDhikrDatabase(@ApplicationContext context: Context): DhikrGoalDatabase {
        return Room.databaseBuilder(
            context,
            DhikrGoalDatabase::class.java,
            "dhikr_goal_database"
        ).build()
    }
    
    @Provides
    @Singleton
    fun provideExoPlayer(@ApplicationContext context: Context): ExoPlayer {
        return ExoPlayer.Builder(context)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(C.USAGE_MEDIA)
                    .setContentType(C.AUDIO_CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setHandleAudioBecomingNoisy(true)
            .build()
    }
}
```

#### **Repository Pattern**
```kotlin
interface DhikrGoalRepository {
    fun getAllGoals(): Flow<List<DhikrGoal>>
    suspend fun updateProgress(goalId: String, newCount: Int)
    suspend fun createGoal(goal: DhikrGoal)
    suspend fun deleteGoal(goalId: String)
}

@Singleton
class DhikrGoalRepositoryImpl @Inject constructor(
    private val goalDao: DhikrGoalDao,
    private val countingService: DhikrCountingService
) : DhikrGoalRepository {
    
    override fun getAllGoals(): Flow<List<DhikrGoal>> {
        return goalDao.getAllGoals().map { entities ->
            entities.map { it.toDhikrGoal() }
        }
    }
    
    override suspend fun updateProgress(goalId: String, newCount: Int) {
        goalDao.updateProgress(goalId, newCount)
        countingService.recordProgress(goalId, newCount)
    }
}
```

---

## **Getting Started**

### **1. Project Setup**
```bash
# Create new Android project in Android Studio
# Use "Empty Activity" template with Kotlin
# Configure build.gradle.kts with dependencies above
```

### **2. Package Structure Creation**
Create the folder structure as defined in Section 1:
```
app/src/main/java/com/theveloper/dhikrgoal/
├── data/
├── di/
├── presentation/
├── ui/
└── utils/
```

### **3. Initial Files to Create**
1. `data/model/Dhikr.kt`
2. `data/model/DhikrGoal.kt`
3. `data/database/DhikrGoalDatabase.kt`
4. `di/DhikrAppModule.kt`
5. `presentation/viewmodel/DhikrDashboardViewModel.kt`
6. `ui/theme/Theme.kt`
7. `presentation/screens/DhikrDashboard.kt`
8. `app/compose_stability.conf`

### **4. Implementation Order**
1. **Data Layer**: Models, Database, DAOs
2. **DI Module**: Set up Hilt and dependencies
3. **UI Layer**: Theme, Components, Screens
4. **ViewModels**: Connect UI with data
5. **Audio Service**: Implement counting logic
6. **Performance**: Add baseline profiles and optimizations

---

## **Success Metrics**

- **App startup time** < 1.5 seconds (with baseline profiles)
- **Audio counting accuracy** 100% reliable loop detection
- **Memory usage** < 150MB for typical usage
- **Battery efficiency** < 2% per hour of audio counting

---

## **Summary**

This comprehensive plan incorporates enterprise-level Android development patterns from PixelPlayer to create a premium dhikr tracking app. The focus on performance, modern architecture, and user experience will result in a professional app that stands out in the spiritual wellness category.

**Key Advantages:**
- Performance-first architecture with baseline profiles
- Modern MVVM with Repository pattern
- Advanced audio counting with Media3
- Premium Material You theming
- Scalable and maintainable codebase

Start with Phase 1 implementation and follow the roadmap for a successful, production-ready app.
