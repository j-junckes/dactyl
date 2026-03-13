#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QtQml>
#include "fingerprintmanager.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    qmlRegisterType<FingerprintManager>("dev.junckes.Dactyl", 1, 0, "FingerprintManager");

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Dactyl", "Main");

    return app.exec();
}
