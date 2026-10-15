plugins {
    id("awrad.android.library")
    alias(libs.plugins.ksp)
    alias(libs.plugins.room)
}

android {
    namespace = "app.awrad.core.database"
}

room {
    // Committed evidence for every shipped version; never delete or rewrite.
    schemaDirectory("$projectDir/schemas")
}

dependencies {
    api(libs.room.runtime)
    implementation(libs.room.ktx)
    ksp(libs.room.compiler)
}
