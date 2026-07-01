import QtQuick

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Honey"
    color: "#ffffff"

    // Authentic Asymmetric XMB Layout Node Placement
    readonly property int xmbX: width * 0.22
    readonly property int xmbY: height * 0.40
    property bool inItemMode: false

    // Mock Live System States (Easily bind these to C++ or system APIs later)
    property int systemBattery: 88
    property int systemVolume: 70
    property string systemTime: Qt.formatDateTime(new Date(), "hh:mm")
    property string systemDate: Qt.formatDateTime(new Date(), "ddd d MMM")

    // ---------------------------------------------------------------
    // Data Architecture
    // ---------------------------------------------------------------
    ListModel {
        id: categoryModel
        ListElement { glyph: "👤"; label: "Users" }
        ListElement { glyph: "🖼"; label: "Photo" }
        ListElement { glyph: "🎵"; label: "Music" }
        ListElement { glyph: "🎬"; label: "Video" }
        ListElement { glyph: "🎮"; label: "Game" }
        ListElement { glyph: "🌐"; label: "Network" }
        ListElement { glyph: "👥"; label: "Friends" }
        ListElement { glyph: "⚙"; label: "Settings" }
        ListElement { glyph: "⏻"; label: "Power" }
    }

    readonly property var itemsByCategory: ({
        "Users":    ["Sign In", "New User", "Manage Accounts"],
        "Photo":    ["Slideshow", "Albums", "Camera Import", "Screenshots"],
        "Music":    ["Playlists", "Artists", "Albums", "Radio", "Podcasts"],
        "Video":    ["Movies", "TV Shows", "Recently Watched", "Streaming"],
        "Game":     ["Library", "Store", "Trophies", "Saved Data"],
        "Network":  ["Wi-Fi", "Ethernet", "Bluetooth", "Remote Play"],
        "Friends":  ["Online Friends", "Messages", "Parties", "Invites"],
        "Settings": ["Display", "Sound", "Accessibility", "Storage", "System"],
        "Power":    ["Sleep", "Restart", "Shut Down"]
    })

    property int categoryIndex: 0
    property int itemIndex: 0

    function currentCategoryLabel() {
        return categoryModel.get(categoryIndex).label
    }

    // High-performance flat model synchronization to prevent GC thrashing
    ListModel { id: subItemModel }

    function syncSubItems() {
        subItemModel.clear();
        var items = itemsByCategory[currentCategoryLabel()] || [];
        for (var i = 0; i < items.length; ++i) {
            subItemModel.append({ "modelData": items[i] });
        }
    }

    onCategoryIndexChanged: syncSubItems()
    Component.onCompleted: syncSubItems()

    // ---------------------------------------------------------------
    // Input & Visual Scene Graph
    // ---------------------------------------------------------------
    Item {
        id: content
        anchors.fill: parent
        focus: true

        Component.onCompleted: content.forceActiveFocus()

        // Fallback Solid Canvas Base
        Rectangle {
            anchors.fill: parent
            color: "#ffffff"
        }

        // Expanded Screen-Space Raymarched Lava Lamp Background
        ShaderEffect {
            id: lavaLamp
            anchors.fill: parent
            property real iTime: 0.0
            property vector2d iResolution: Qt.vector2d(width, height)
            fragmentShader: "qrc:/shaders/lavalamp.frag.qsb"

            NumberAnimation on iTime {
                from: 0; to: 1000000
                duration: 1000000000
                loops: Animation.Infinite
                running: true
            }
        }

        // -----------------------------------------------------------
        // FUTURE-PROOF MODULAR SYSTEM STATUS BAR (Top Right)
        // -----------------------------------------------------------

        // Timer to tick system time updates
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: {
                var d = new Date()
                root.systemTime = Qt.formatDateTime(d, "hh:mm")
                root.systemDate = Qt.formatDateTime(d, "ddd d MMM")
            }
        }

        // Reusable Custom Status UI Component Template
        component StatusPill : Rectangle {
            property string icon: ""
            property string textValue: ""
            property string subText: ""

            width: pillRow.spacing + iconText.width + (subTextText.visible ? subTextText.width + 8 : 0) + 32
            height: 40
            radius: 12
            color: "#ffffff"
            opacity: 0.75

            Row {
                id: pillRow
                anchors.centerIn: parent
                spacing: 8

                Text {
                    text: icon
                    font.pixelSize: 16
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: iconText
                    text: textValue
                    color: "#151515"
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "Sans"
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    id: subTextText
                    text: subText
                    color: "#666666"
                    font.pixelSize: 13
                    font.family: "Sans"
                    visible: subText !== ""
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Horizontal status bar container layout
        Row {
            id: statusBar
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 20
            spacing: 12

            // ITEM 1: Volume Indicator
            StatusPill {
                icon: "🔊"
                textValue: root.systemVolume + "%"
            }

            // ITEM 2: Battery Percentage Indicator
            StatusPill {
                icon: "🔋"
                textValue: root.systemBattery + "%"
                // Changes subtext warning dynamically based on capacity limits
                subText: root.systemBattery < 20 ? "Low" : ""
            }

            // ITEM 3: Clock and Date Module
            StatusPill {
                icon: "🕒"
                textValue: root.systemTime
                subText: "·  " + root.systemDate
            }

            /* 💡 HOW TO ADD NEW ITEMS IN THE FUTURE:
               Simply uncomment or drop a block like this right here inside this Row:

            StatusPill {
                icon: "📶"
                textValue: "Wi-Fi"
                subText: "Connected"
            }
            */
        }

        // Subtle horizontal guide line
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            y: root.xmbY
            height: 1
            color: "#151515"
            opacity: 0.08
        }

        // Horizontal Category Row
        ListView {
            id: categoryBar
            orientation: ListView.Horizontal
            x: 0
            width: parent.width
            y: root.xmbY - height / 2
            height: 160
            model: categoryModel
            currentIndex: root.categoryIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: root.xmbX - 60
            preferredHighlightEnd: root.xmbX + 60
            interactive: false
            spacing: 45
            opacity: root.inItemMode ? 0.30 : 1.0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            delegate: Item {
                id: catDelegate
                width: 120
                height: categoryBar.height
                readonly property bool isCurrent: ListView.isCurrentItem

                // Dynamic "Padding" Box — Expands to 124x124 when selected
                Rectangle {
                    anchors.centerIn: parent
                    width: catDelegate.isCurrent ? 124 : 85
                    height: catDelegate.isCurrent ? 124 : 85
                    radius: 24
                    color: "#ffffff"
                    opacity: catDelegate.isCurrent ? 0.55 : 0.0

                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    scale: catDelegate.isCurrent ? 1.30 : 0.85
                    opacity: catDelegate.isCurrent ? 1.0 : 0.50
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: glyph
                        font.pixelSize: 44
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: label
                        color: "#151515"
                        font.pixelSize: 14
                        font.bold: true
                        font.family: "Sans"
                        visible: catDelegate.isCurrent
                    }
                }
            }
        }

        // Vertical Sub-Item Menu (Featuring Accordion Component Resizing)
        ListView {
            id: itemList
            width: 340
            height: 440

            x: root.xmbX + 85
            y: root.xmbY - height / 2 + (root.inItemMode ? 0 : 15)

            model: subItemModel
            currentIndex: root.itemIndex
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: height / 2 - 28
            preferredHighlightEnd: height / 2 + 28
            interactive: false
            spacing: 6

            opacity: root.inItemMode ? 1.0 : 0.0
            visible: opacity > 0.0
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }

            delegate: Item {
                id: itemDelegate
                width: itemList.width

                // Dynamic Vertical Padding: Expands from 42px to 56px when active
                height: itemDelegate.isCurrent ? 56 : 42
                readonly property bool isCurrent: ListView.isCurrentItem

                Behavior on height {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    radius: 8
                    color: "#ffffff"
                    opacity: itemDelegate.isCurrent ? 0.75 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }

                Text {
                    id: itemText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left

                    // Dynamic Horizontal Padding: Text shifts inwards when item is active
                    anchors.leftMargin: itemDelegate.isCurrent ? 24 : 14

                    text: modelData
                    color: "#151515"
                    font.pixelSize: 17
                    font.family: "Sans"
                    font.bold: itemDelegate.isCurrent

                    // Hardware-accelerated font scale transformations
                    scale: itemDelegate.isCurrent ? 1.10 : 1.0
                    transformOrigin: Item.Left
                    opacity: itemDelegate.isCurrent ? 1.0 : 0.55

                    Behavior on anchors.leftMargin {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
            }
        }

        // Interface Context Footer Hints
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 20
            width: footer.width + 48
            height: footer.height + 18
            radius: 12
            color: "#ffffff"
            opacity: 0.75
        }
        Text {
            id: footer
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottomMargin: 29
            color: "#151515"
            font.pixelSize: 14
            font.family: "Sans"
            text: root.inItemMode
                  ? "↑↓ Navigate   ↵ Select   ⌫ Back"
                  : "←→ Navigate   ↵ Open   " + root.currentCategoryLabel()
        }

        // -----------------------------------------------------------
        // Input Command Router
        // -----------------------------------------------------------
        Keys.onPressed: (event) => {
            if (!root.inItemMode) {
                if (event.key === Qt.Key_Left) {
                    root.categoryIndex = (root.categoryIndex - 1 + categoryModel.count) % categoryModel.count;
                    root.itemIndex = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    root.categoryIndex = (root.categoryIndex + 1) % categoryModel.count;
                    root.itemIndex = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (subItemModel.count > 0) {
                        root.inItemMode = true;
                    }
                    event.accepted = true;
                }
            } else {
                if (event.key === Qt.Key_Up) {
                    root.itemIndex = (root.itemIndex - 1 + subItemModel.count) % subItemModel.count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    root.itemIndex = (root.itemIndex + 1) % subItemModel.count;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Backspace || event.key === Qt.Key_Escape) {
                    root.inItemMode = false;
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    console.log("Executed Application Option:", root.currentCategoryLabel(), "->", subItemModel.get(root.itemIndex).modelData);
                    event.accepted = true;
                }
            }
        }
    }
}
