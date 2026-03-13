import QtQuick
import QtQuick.Shapes
import dev.junckes.Dactyl 1.0

Window {
    id: root
    width: 700
    height: 500
    minimumWidth: 700
    minimumHeight: 500
    visible: true
    title: "Dactyl"
    color: "#0d1117"

    FingerprintManager {
        id: fp
        onScanFailed: shakeAnim.restart()
        onVerifyComplete: function(matched, finger) {
            if (matched) {
                root.matchedFinger = finger
                root.showMatch = true
                matchTimer.restart()
            }
        }
    }

    property string matchedFinger: ""
    property bool showMatch: false

    Timer {
        id: matchTimer
        interval: 2500
        onTriggered: { root.showMatch = false; root.matchedFinger = "" }
    }

    property var leftFingers: [
        { fingerId: "left-thumb",         label: "Thumb"  },
        { fingerId: "left-index-finger",  label: "Index"  },
        { fingerId: "left-middle-finger", label: "Middle" },
        { fingerId: "left-ring-finger",   label: "Ring"   },
        { fingerId: "left-little-finger", label: "Little" }
    ]
    property var rightFingers: [
        { fingerId: "right-thumb",         label: "Thumb"  },
        { fingerId: "right-index-finger",  label: "Index"  },
        { fingerId: "right-middle-finger", label: "Middle" },
        { fingerId: "right-ring-finger",   label: "Ring"   },
        { fingerId: "right-little-finger", label: "Little" }
    ]

    component FingerButton: Rectangle {
        id: btn
        property string fingerId: ""
        property string fingerLabel: ""
        property bool enrolled: false
        property bool enrolling: false
        property bool matched: false
        property bool canInteract: true
        signal enrollRequested
        signal deleteRequested

        width: 86
        height: 46
        radius: 10

        color: {
            if (matched)   return "#1a4a1a"
            if (enrolling) return "#3a2e00"
            if (enrolled)  return "#0d2044"
            return "#161b22"
        }

        border.color: {
            if (matched)   return "#3fb950"
            if (enrolling) return "#f0b429"
            if (enrolled)  return "#388bfd"
            return "#30363d"
        }
        border.width: (matched || enrolling || enrolled) ? 1.5 : 1

        Behavior on color       { ColorAnimation { duration: 180 } }
        Behavior on border.color { ColorAnimation { duration: 180 } }

        Text {
            anchors.centerIn: parent
            text: btn.fingerLabel
            color: {
                if (btn.matched)   return "#3fb950"
                if (btn.enrolling) return "#f0b429"
                if (btn.enrolled)  return "#58a6ff"
                return "#6e7681"
            }
            font.pixelSize: 13
            font.weight: Font.Medium
            Behavior on color { ColorAnimation { duration: 180 } }
        }

        SequentialAnimation {
            id: liftPulse
            running: btn.enrolling && fp.isWaitingForLift
            loops: Animation.Infinite
            NumberAnimation { target: btn; property: "opacity"; to: 0.35; duration: 380 }
            NumberAnimation { target: btn; property: "opacity"; to: 1.0;  duration: 380 }
            onStopped: btn.opacity = 1.0
        }

        MouseArea {
            anchors.fill: parent
            enabled: btn.canInteract && fp.deviceAvailable
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: btn.enrolled ? btn.deleteRequested() : btn.enrollRequested()
        }
    }

    Item {
        anchors.centerIn: parent
        width: leftCol.width + 32 + centerCol.width + 32 + rightCol.width
        height: Math.max(leftCol.height, centerCol.height, rightCol.height)

        Column {
            id: leftCol
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "Left Hand"
                color: "#3d444d"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
                bottomPadding: 2
            }
            Repeater {
                model: root.leftFingers
                FingerButton {
                    fingerId: modelData.fingerId
                    fingerLabel: modelData.label
                    enrolled: fp.enrolledFingers.indexOf(modelData.fingerId) !== -1
                    enrolling: fp.enrollingFinger === modelData.fingerId
                    matched: root.showMatch && root.matchedFinger === modelData.fingerId
                    canInteract: fp.state === FingerprintManager.Idle
                    onEnrollRequested: fp.startEnrollment(modelData.fingerId)
                    onDeleteRequested: { deletePopup.pendingId = modelData.fingerId; deletePopup.pendingLabel = modelData.label; deletePopup.visible = true }
                }
            }
        }

        Column {
            id: centerCol
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14
            width: 180

            Item {
                width: 160
                height: 160
                anchors.horizontalCenter: parent.horizontalCenter

                transform: Translate { id: shakeTranslate; x: 0 }

                SequentialAnimation {
                    id: shakeAnim
                    NumberAnimation { target: shakeTranslate; property: "x"; to:  12; duration: 45 }
                    NumberAnimation { target: shakeTranslate; property: "x"; to: -12; duration: 45 }
                    NumberAnimation { target: shakeTranslate; property: "x"; to:   9; duration: 45 }
                    NumberAnimation { target: shakeTranslate; property: "x"; to:  -9; duration: 45 }
                    NumberAnimation { target: shakeTranslate; property: "x"; to:   4; duration: 45 }
                    NumberAnimation { target: shakeTranslate; property: "x"; to:   0; duration: 45 }
                }

                Shape {
                    anchors.centerIn: parent
                    width: 160; height: 160
                    ShapePath {
                        strokeColor: "#21262d"
                        strokeWidth: 9
                        fillColor: "transparent"
                        PathAngleArc {
                            centerX: 80; centerY: 80
                            radiusX: 68; radiusY: 68
                            startAngle: 0; sweepAngle: 360
                        }
                    }
                }

                Shape {
                    anchors.centerIn: parent
                    width: 160; height: 160
                    visible: fp.state === FingerprintManager.Enrolling

                    ShapePath {
                        id: enrollArcPath
                        strokeWidth: 9
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        strokeColor: fp.isWaitingForLift ? "#f0b429" : "#3fb950"
                        Behavior on strokeColor { ColorAnimation { duration: 200 } }
                        PathAngleArc {
                            centerX: 80; centerY: 80
                            radiusX: 68; radiusY: 68
                            startAngle: -90
                            sweepAngle: fp.enrollProgress / 100 * 360
                            Behavior on sweepAngle { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                Shape {
                    anchors.centerIn: parent
                    width: 160; height: 160
                    visible: fp.state === FingerprintManager.Verifying

                    NumberAnimation on rotation {
                        running: fp.state === FingerprintManager.Verifying
                        from: 0; to: 360; duration: 1100
                        loops: Animation.Infinite
                    }

                    ShapePath {
                        strokeColor: "#58a6ff"
                        strokeWidth: 9
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc {
                            centerX: 80; centerY: 80
                            radiusX: 68; radiusY: 68
                            startAngle: -90; sweepAngle: 260
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            if (!fp.deviceAvailable)                        return "!"
                            if (fp.state === FingerprintManager.Enrolling && fp.isWaitingForLift) return "↑"
                            if (fp.state === FingerprintManager.Enrolling)  return fp.enrollProgress + "%"
                            if (fp.state === FingerprintManager.Verifying)  return "?"
                            if (root.showMatch)                              return "✓"
                            return ""
                        }
                        color: {
                            if (!fp.deviceAvailable)                        return "#f85149"
                            if (fp.state === FingerprintManager.Enrolling && fp.isWaitingForLift) return "#f0b429"
                            if (fp.state === FingerprintManager.Enrolling)  return "#3fb950"
                            if (fp.state === FingerprintManager.Verifying)  return "#58a6ff"
                            if (root.showMatch)                              return "#3fb950"
                            return "#3d444d"
                        }
                        font.pixelSize: 30
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: fp.statusMessage
                color: "#8b949e"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                width: 180
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    visible: fp.state === FingerprintManager.Idle && fp.deviceAvailable
                    width: 80; height: 32
                    radius: 7
                    color: mouseVerify.containsMouse ? "#1c2128" : "#161b22"
                    border.color: "#30363d"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "Verify"; color: "#58a6ff"; font.pixelSize: 13 }

                    MouseArea {
                        id: mouseVerify
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fp.startVerify()
                    }
                }

                Rectangle {
                    visible: fp.state !== FingerprintManager.Idle
                    width: 80; height: 32
                    radius: 7
                    color: mouseCancel.containsMouse ? "#2d1515" : "#161b22"
                    border.color: "#f85149"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#f85149"; font.pixelSize: 13 }

                    MouseArea {
                        id: mouseCancel
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fp.stopAction()
                    }
                }
            }
        }

        Column {
            id: rightCol
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                text: "Right Hand"
                color: "#3d444d"
                font.pixelSize: 11
                anchors.horizontalCenter: parent.horizontalCenter
                bottomPadding: 2
            }
            Repeater {
                model: root.rightFingers
                FingerButton {
                    fingerId: modelData.fingerId
                    fingerLabel: modelData.label
                    enrolled: fp.enrolledFingers.indexOf(modelData.fingerId) !== -1
                    enrolling: fp.enrollingFinger === modelData.fingerId
                    matched: root.showMatch && root.matchedFinger === modelData.fingerId
                    canInteract: fp.state === FingerprintManager.Idle
                    onEnrollRequested: fp.startEnrollment(modelData.fingerId)
                    onDeleteRequested: { deletePopup.pendingId = modelData.fingerId; deletePopup.pendingLabel = modelData.label; deletePopup.visible = true }
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.55)
        visible: deletePopup.visible
        z: 9
        MouseArea { anchors.fill: parent; onClicked: deletePopup.visible = false }
    }

    Rectangle {
        id: deletePopup
        visible: false
        anchors.centerIn: parent
        width: 270
        height: 130
        radius: 12
        color: "#161b22"
        border.color: "#30363d"
        border.width: 1
        z: 10

        property string pendingId: ""
        property string pendingLabel: ""

        Column {
            anchors.centerIn: parent
            spacing: 18

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Delete " + deletePopup.pendingLabel + "?"
                color: "#c9d1d9"
                font.pixelSize: 14
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Rectangle {
                    width: 88; height: 34
                    radius: 7
                    color: mc1.containsMouse ? "#21262d" : "#161b22"
                    border.color: "#30363d"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "Cancel"; color: "#8b949e"; font.pixelSize: 13 }
                    MouseArea { id: mc1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: deletePopup.visible = false }
                }

                Rectangle {
                    width: 88; height: 34
                    radius: 7
                    color: mc2.containsMouse ? "#3d1515" : "#2d1010"
                    border.color: "#f85149"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text { anchors.centerIn: parent; text: "Delete"; color: "#f85149"; font.pixelSize: 13 }
                    MouseArea {
                        id: mc2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            fp.deleteEnrolledFinger(deletePopup.pendingId)
                            deletePopup.visible = false
                        }
                    }
                }
            }
        }
    }
}
