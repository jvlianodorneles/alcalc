#include <QApplication>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QFont>
#include <QFontDatabase>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QQuickStyle>
#include <QUrl>
#include <QWindow>
#include <iostream>

#include "backend.h"
#include "systemtheme.h"

int main(int argc, char *argv[]) {
    // If CLI calculation arguments are supplied without starting GUI, we can run fast
    if (argc > 1) {
        const QString firstArg = QString::fromUtf8(argv[1]);
        if (firstArg == QStringLiteral("-v") || firstArg == QStringLiteral("--version")) {
            std::cout << "Alcalc 1.0.0 (Apple Calculator Language for Omarchy)" << std::endl;
            return 0;
        }
        if (firstArg == QStringLiteral("-h") || firstArg == QStringLiteral("--help")) {
            std::cout << "Alcalc - An implementation of the Apple Calculator Language for Omarchy\n\n"
                      << "Usage:\n"
                      << "  alcalc                     Launch the graphical calculator interface\n"
                      << "  alcalc \"<expression>\"       Evaluate an expression directly in the terminal\n"
                      << "  alcalc --explain \"<expr>\"   Evaluate with step-by-step reduction trace\n"
                      << "  alcalc --json \"<expr>\"      Output evaluation result as JSON\n"
                      << "\nExamples:\n"
                      << "  alcalc \"1..10 INSERT +\"\n"
                      << "  alcalc \"6/3+2*5\"\n"
                      << "  alcalc \"10 20 30 MEAN\"\n"
                      << "  alcalc --explain \"5 TOTHE 2 + 1\"\n";
            return 0;
        }

        // Check if evaluating CLI expression
        bool explain = false;
        bool jsonOutput = false;
        QString expr;

        for (int i = 1; i < argc; ++i) {
            const QString arg = QString::fromUtf8(argv[i]);
            if (arg == QStringLiteral("--explain") || arg == QStringLiteral("-e")) {
                explain = true;
            } else if (arg == QStringLiteral("--json") || arg == QStringLiteral("-j")) {
                jsonOutput = true;
            } else if (!arg.startsWith('-')) {
                if (!expr.isEmpty())
                    expr += " ";
                expr += arg;
            }
        }

        if (!expr.isEmpty()) {
            QApplication app(argc, argv);
            Backend backend;
            const bool success = backend.evaluateCli(expr, explain, jsonOutput);
            return success ? 0 : 1;
        }
    }

    // Launch Graphical Application
    QApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("alcalc"));
    app.setDesktopFileName(QStringLiteral("alcalc"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("alcalc"), QIcon(QStringLiteral(":/icons/alcalc.svg"))));
    app.setOrganizationName(QStringLiteral("Omacom"));
    app.setOrganizationDomain(QStringLiteral("omacom.io"));

    QQuickStyle::setStyle(QStringLiteral("Material"));

    Backend backend(&app);
    SystemTheme systemTheme(&app);
    backend.setDarkMode(systemTheme.darkMode());
    backend.setTextScale(systemTheme.textScale());

    QObject::connect(&systemTheme, &SystemTheme::darkModeChanged, &backend,
                     &Backend::setDarkMode);
    QObject::connect(&systemTheme, &SystemTheme::textScaleChanged, &backend,
                     &Backend::setTextScale);

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, &app,
                     [](const QList<QQmlError> &warnings) {
        for (const QQmlError &warning : warnings)
            qWarning().noquote() << warning.toString();
    });

    engine.rootContext()->setContextProperty(QStringLiteral("backend"), &backend);

    engine.load(QUrl(QStringLiteral("qrc:/Main.qml")));
    if (engine.rootObjects().isEmpty()) {
        qCritical() << "Could not load Alcalc interface.";
        return -1;
    }

    backend.setParentWindow(qobject_cast<QWindow *>(engine.rootObjects().constFirst()));

    return app.exec();
}
