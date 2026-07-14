Place optional vendor SDK jars in this directory only while developing this
package directly.

For Chainway C66 broadcast auto-configuration, use the official Chainway
`cw-deviceapi*.jar` from Chainway's Android Studio 2D broadcast SDK package.
The plugin loads Chainway APIs by reflection, so the package still compiles and
runs when no vendor jar is present.

For a consuming app, prefer placing the jar in the app's own `android/app/libs`
directory and adding a Gradle dependency such as:

```groovy
dependencies {
    implementation fileTree(dir: 'libs', include: ['*.jar'])
}
```

Do not publish vendor jars with this package unless the vendor license permits
redistribution.
