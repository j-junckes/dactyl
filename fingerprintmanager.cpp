#include "fingerprintmanager.h"
#include <QtDBus>

FingerprintManager::FingerprintManager(QObject *parent)
    : QObject{parent}
{
    QDBusInterface manager("net.reactivated.Fprint",
                           "/net/reactivated/Fprint/Manager",
                           "net.reactivated.Fprint.Manager",
                           QDBusConnection::systemBus());

    QDBusReply<QDBusObjectPath> deviceReply = manager.call("GetDefaultDevice");
    if (!deviceReply.isValid()) {
        updateStatus("No fingerprint reader found.");
        return;
    }

    const QString path = deviceReply.value().path();

    m_deviceInterface = new QDBusInterface("net.reactivated.Fprint", path,
                                           "net.reactivated.Fprint.Device",
                                           QDBusConnection::systemBus(), this);

    QDBusInterface props("net.reactivated.Fprint", path,
                         "org.freedesktop.DBus.Properties",
                         QDBusConnection::systemBus());
    QDBusReply<QDBusVariant> stagesReply = props.call("Get",
        "net.reactivated.Fprint.Device", "num-enroll-stages");
    if (stagesReply.isValid())
        m_stagesNeeded = stagesReply.value().variant().toInt();

    QDBusConnection::systemBus().connect("net.reactivated.Fprint", path, "net.reactivated.Fprint.Device",
                "EnrollStatus", this, SLOT(handleEnrollStatus(QString, bool)));
    QDBusConnection::systemBus().connect("net.reactivated.Fprint", path, "net.reactivated.Fprint.Device",
                "VerifyStatus", this, SLOT(handleVerifyStatus(QString, bool)));
    QDBusConnection::systemBus().connect("net.reactivated.Fprint", path, "net.reactivated.Fprint.Device",
                "VerifyFingerSelected", this, SLOT(handleVerifyFingerSelected(QString)));

    m_deviceAvailable = true;
    emit deviceAvailableChanged();
    refreshEnrolledFingers();
    updateStatus("Ready.");
}

void FingerprintManager::startEnrollment(const QString &fingerName)
{
    if (!m_deviceInterface || m_state != Idle) return;

    m_enrollProgress = 0;
    m_stagesCompleted = 0;
    m_isWaitingForLift = false;
    m_enrollingFinger = fingerName;
    emit enrollProgressChanged();
    emit isWaitingForLiftChanged();
    emit enrollingFingerChanged();

    QDBusReply<void> claim = m_deviceInterface->call("Claim", qEnvironmentVariable("USER"));
    if (!claim.isValid()) {
        m_enrollingFinger.clear();
        emit enrollingFingerChanged();
        updateStatus("Could not claim device.");
        return;
    }

    m_deviceInterface->call("EnrollStart", fingerName);
    m_state = Enrolling;
    emit stateChanged();
    updateStatus("Place your finger on the sensor.");
}

void FingerprintManager::stopEnrollment()
{
    if (!m_deviceInterface || m_state != Enrolling) return;
    m_deviceInterface->call("EnrollStop");
    release();
    m_isWaitingForLift = false;
    m_enrollingFinger.clear();
    m_state = Idle;
    emit isWaitingForLiftChanged();
    emit enrollingFingerChanged();
    emit stateChanged();
    updateStatus("Ready.");
}

void FingerprintManager::startVerify()
{
    if (!m_deviceInterface || m_state != Idle) return;
    QDBusReply<void> claim = m_deviceInterface->call("Claim", qEnvironmentVariable("USER"));
    if (!claim.isValid()) {
        updateStatus("Could not claim device.");
        return;
    }
    m_deviceInterface->call("VerifyStart", "any");
    m_state = Verifying;
    emit stateChanged();
    updateStatus("Place any finger on the sensor.");
}

void FingerprintManager::stopVerify()
{
    if (!m_deviceInterface || m_state != Verifying) return;
    m_deviceInterface->call("VerifyStop");
    release();
    m_lastVerifyFinger.clear();
    m_state = Idle;
    emit stateChanged();
    updateStatus("Ready.");
}

void FingerprintManager::deleteEnrolledFinger(const QString &fingerName)
{
    if (!m_deviceInterface) return;
    QDBusReply<void> claim = m_deviceInterface->call("Claim", qEnvironmentVariable("USER"));
    if (!claim.isValid()) {
        updateStatus("Could not claim device.");
        return;
    }
    m_deviceInterface->call("DeleteEnrolledFinger", fingerName);
    release();
    refreshEnrolledFingers();
}

void FingerprintManager::refreshEnrolledFingers()
{
    if (!m_deviceInterface) return;
    QDBusReply<QStringList> reply = m_deviceInterface->call(
        "ListEnrolledFingers", qEnvironmentVariable("USER"));
    m_enrolledFingers = reply.isValid() ? reply.value() : QStringList{};
    emit enrolledFingersChanged();
}

void FingerprintManager::stopAction()
{
    if (m_state == Enrolling) stopEnrollment();
    else if (m_state == Verifying) stopVerify();
}

void FingerprintManager::handleEnrollStatus(const QString &result, bool done)
{
    Q_UNUSED(done)

    if (m_isWaitingForLift) {
        m_isWaitingForLift = false;
        emit isWaitingForLiftChanged();
    }

    if (result == "enroll-stage-passed") {
        m_stagesCompleted++;
        m_enrollProgress = qMin(99, m_stagesCompleted * 100 / m_stagesNeeded);
        emit enrollProgressChanged();
        m_isWaitingForLift = true;
        emit isWaitingForLiftChanged();
        updateStatus("Lift your finger.");
    } else if (result == "enroll-completed") {
        m_enrollProgress = 100;
        emit enrollProgressChanged();
        m_enrollingFinger.clear();
        emit enrollingFingerChanged();
        m_deviceInterface->call("EnrollStop");
        release();
        m_state = Idle;
        emit stateChanged();
        refreshEnrolledFingers();
        updateStatus("Finger enrolled.");
        emit enrollmentComplete(true);
    } else if (result == "enroll-failed" || result == "enroll-unknown-error") {
        m_enrollingFinger.clear();
        emit enrollingFingerChanged();
        m_deviceInterface->call("EnrollStop");
        release();
        m_state = Idle;
        emit stateChanged();
        updateStatus("Enrollment failed.");
        emit enrollmentComplete(false);
        emit scanFailed();
    } else if (result == "enroll-retry-scan" || result == "enroll-swipe-too-short") {
        updateStatus("Scan again.");
    } else if (result == "enroll-finger-not-present") {
        updateStatus("Place your finger on the sensor.");
    }
}

void FingerprintManager::handleVerifyStatus(const QString &result, bool done)
{
    if (result == "verify-match") {
        updateStatus("Match!");
        emit verifyComplete(true, m_lastVerifyFinger);
    } else if (result == "verify-no-match") {
        updateStatus("No match.");
        emit scanFailed();
        emit verifyComplete(false, QString());
    } else if (result == "verify-retry-scan" || result == "verify-swipe-too-short") {
        updateStatus("Scan again.");
    } else if (result == "verify-finger-not-present") {
        updateStatus("Place your finger on the sensor.");
    } else if (result == "verify-unknown-error") {
        updateStatus("Verify error.");
    }

    if (done) {
        m_deviceInterface->call("VerifyStop");
        release();
        m_lastVerifyFinger.clear();
        m_state = Idle;
        emit stateChanged();
    }
}

void FingerprintManager::handleVerifyFingerSelected(const QString &fingerName)
{
    m_lastVerifyFinger = fingerName;
}

void FingerprintManager::updateStatus(const QString &msg)
{
    m_statusMessage = msg;
    emit statusMessageChanged();
}

void FingerprintManager::release()
{
    if (m_deviceInterface)
        m_deviceInterface->call("Release");
}
