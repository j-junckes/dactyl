#ifndef FINGERPRINTMANAGER_H
#define FINGERPRINTMANAGER_H

#include <QObject>
#include <QDBusInterface>
#include <QStringList>

class FingerprintManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusMessageChanged)
    Q_PROPERTY(int enrollProgress READ enrollProgress NOTIFY enrollProgressChanged)
    Q_PROPERTY(bool isWaitingForLift READ isWaitingForLift NOTIFY isWaitingForLiftChanged)
    Q_PROPERTY(QStringList enrolledFingers READ enrolledFingers NOTIFY enrolledFingersChanged)
    Q_PROPERTY(bool deviceAvailable READ deviceAvailable NOTIFY deviceAvailableChanged)
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(QString enrollingFinger READ enrollingFinger NOTIFY enrollingFingerChanged)

public:
    enum State { Idle, Enrolling, Verifying };
    Q_ENUM(State)

    explicit FingerprintManager(QObject *parent = nullptr);

    Q_INVOKABLE void startEnrollment(const QString &fingerName);
    Q_INVOKABLE void stopEnrollment();
    Q_INVOKABLE void startVerify();
    Q_INVOKABLE void stopVerify();
    Q_INVOKABLE void deleteEnrolledFinger(const QString &fingerName);
    Q_INVOKABLE void refreshEnrolledFingers();
    Q_INVOKABLE void stopAction();

    QString statusMessage() const { return m_statusMessage; }
    int enrollProgress() const { return m_enrollProgress; }
    bool isWaitingForLift() const { return m_isWaitingForLift; }
    QStringList enrolledFingers() const { return m_enrolledFingers; }
    bool deviceAvailable() const { return m_deviceAvailable; }
    State state() const { return m_state; }
    QString enrollingFinger() const { return m_enrollingFinger; }

signals:
    void statusMessageChanged();
    void enrollProgressChanged();
    void isWaitingForLiftChanged();
    void enrolledFingersChanged();
    void deviceAvailableChanged();
    void stateChanged();
    void enrollingFingerChanged();
    void enrollmentComplete(bool success);
    void verifyComplete(bool matched, const QString &fingerUsed);
    void scanFailed();

private slots:
    void handleEnrollStatus(const QString &result, bool done);
    void handleVerifyStatus(const QString &result, bool done);
    void handleVerifyFingerSelected(const QString &fingerName);

private:
    void updateStatus(const QString &msg);
    void release();

    QDBusInterface *m_deviceInterface = nullptr;
    QString m_statusMessage;
    int m_enrollProgress = 0;
    int m_stagesNeeded = 5;
    int m_stagesCompleted = 0;
    bool m_isWaitingForLift = false;
    QStringList m_enrolledFingers;
    bool m_deviceAvailable = false;
    State m_state = Idle;
    QString m_enrollingFinger;
    QString m_lastVerifyFinger;
};

#endif
