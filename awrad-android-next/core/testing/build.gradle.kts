plugins {
    id("awrad.jvm.library")
}

dependencies {
    api(project(":core:domain"))
    api(libs.junit)
    api(libs.kotlinx.coroutines.test)
}
