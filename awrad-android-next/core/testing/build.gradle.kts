plugins {
    id("awrad.jvm.library")
}

dependencies {
    api(project(":core:domain"))
    api(libs.junit)
    api(libs.kotlinx.coroutines.test)
    // The fixture runner reads contracts/ JSON as a tree; no generated serializers needed.
    api(libs.kotlinx.serialization.json)
}
