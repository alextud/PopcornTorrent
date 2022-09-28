// swift-tools-version:5.4.0
import PackageDescription

let package = Package(
    name: "PopcornTorrent",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12), .tvOS(.v12), .macOS(.v11)
    ],
    products: [
        .library(name: "PopcornTorrent", targets: ["PopcornTorrent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/alextud/GCDWebServer", .branch("swift-package-manager")),
    ],
    targets: [
        .target(
            name: "PopcornTorrent",
            dependencies: ["GCDWebServer"],
            path: "PopcornTorrent/Sources",
            exclude: [],
            cxxSettings: [
                .define("TARGET_OS_IOS", .when(platforms: [.iOS])),
                .define("TARGET_OS_TV", .when(platforms: [.tvOS])),
                .define("TARGET_OS_MAC", .when(platforms: [.macOS])),
                .define("BOOST_ASIO_HASH_MAP_BUCKETS", to: "1021"),
                .define("TORRENT_ABI_VERSION", to: "3"),
                .headerSearchPath("../../include/"),
            ],
            linkerSettings: [
                .linkedFramework("SystemConfiguration")
            ]
        ),
        .testTarget(name: "PopcornTorrent-Tests",
                    dependencies: [.targetItem(name: "PopcornTorrent", condition: nil)],
                    path: "PopcornTorrentTests",
                    resources: [.process("Test.torrent")],
                    linkerSettings: [
                        .linkedFramework("MediaPlayer")
                    ]
                   )
    ],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx17
)
