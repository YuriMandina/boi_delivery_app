allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- BLOCO DE CORREÇÃO B2B (LIFECYCLE SEGURO) ---
// Injeta dinamicamente o namespace usando o pluginManager em vez do afterEvaluate
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            try {
                // Usamos Reflection para não depender das classes Java/Kotlin do AGP diretamente no root script
                val getNamespace = androidExt.javaClass.getMethod("getNamespace")
                val currentNamespace = getNamespace.invoke(androidExt) as? String
                
                if (currentNamespace == null) {
                    val setNamespace = androidExt.javaClass.getMethod("setNamespace", String::class.java)
                    var pluginNs = project.group.toString()
                    if (pluginNs.isEmpty()) {
                        pluginNs = "com.example.${project.name}"
                    }
                    setNamespace.invoke(androidExt, pluginNs)
                }
            } catch (e: Exception) {
                // Ignora falhas para que a app compile mesmo que o plugin já não requeira namespace
            }
        }
    }
}
// -------------------------------------------------