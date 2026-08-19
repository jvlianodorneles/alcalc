#include "backend.h"

#include <QClipboard>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJSEngine>
#include <QJSValue>
#include <QJSValueIterator>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QStandardPaths>
#include <iostream>

Backend::Backend(QObject *parent) : QObject(parent) {
    loadState();
}

Backend::~Backend() {
    saveState();
    delete m_jsEngine;
}

void Backend::setDarkMode(bool darkMode) {
    if (m_darkMode == darkMode)
        return;

    m_darkMode = darkMode;
    emit darkModeChanged(m_darkMode);
    emit themeColorsChanged();
}

void Backend::setTextScale(qreal textScale) {
    if (qFuzzyCompare(m_textScale, textScale))
        return;

    m_textScale = textScale;
    emit textScaleChanged(m_textScale);
}

QColor Backend::themeBackground() const {
    return m_darkMode ? QColor(QStringLiteral("#1e1e2e")) : QColor(QStringLiteral("#eff1f5"));
}

QColor Backend::themeForeground() const {
    return m_darkMode ? QColor(QStringLiteral("#cdd6f4")) : QColor(QStringLiteral("#4c4f69"));
}

QColor Backend::themeSurface() const {
    return m_darkMode ? QColor(QStringLiteral("#252538")) : QColor(QStringLiteral("#e6e9ef"));
}

QColor Backend::themeSurfaceVariant() const {
    return m_darkMode ? QColor(QStringLiteral("#313244")) : QColor(QStringLiteral("#dce0e8"));
}

QColor Backend::themeAccent() const {
    return m_darkMode ? QColor(QStringLiteral("#89b4fa")) : QColor(QStringLiteral("#1e66f5"));
}

QColor Backend::themeBorder() const {
    return m_darkMode ? QColor(QStringLiteral("#45475a")) : QColor(QStringLiteral("#ccd0da"));
}

QColor Backend::themeSelection() const {
    return m_darkMode ? QColor(QStringLiteral("#585b70")) : QColor(QStringLiteral("#bcc0cc"));
}

QColor Backend::themeMuted() const {
    return m_darkMode ? QColor(QStringLiteral("#a6adc8")) : QColor(QStringLiteral("#6c6f85"));
}

QColor Backend::themeError() const {
    return m_darkMode ? QColor(QStringLiteral("#f38ba8")) : QColor(QStringLiteral("#d20f39"));
}

QColor Backend::themeSuccess() const {
    return m_darkMode ? QColor(QStringLiteral("#a6e3a1")) : QColor(QStringLiteral("#40a02b"));
}

void Backend::copyToClipboard(const QString &text) {
    if (QClipboard *clipboard = QGuiApplication::clipboard()) {
        clipboard->setText(text);
    }
    // Also use wl-copy for native Wayland clipboard compatibility
    QProcess::startDetached(QStringLiteral("wl-copy"), {text});
}

QString Backend::stateDirectoryPath() const {
    const QString home = QDir::homePath();
    return home + QStringLiteral("/.local/state/omarchy/alcalc");
}

QString Backend::stateFilePath(const QString &filename) const {
    return stateDirectoryPath() + QStringLiteral("/") + filename;
}

void Backend::loadState() {
    const QString dirPath = stateDirectoryPath();
    QDir().mkpath(dirPath);

    // 1. History
    QFile histFile(stateFilePath(QStringLiteral("history.json")));
    if (histFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(histFile.readAll());
        if (doc.isArray()) {
            m_history = doc.array().toVariantList();
            emit historyChanged();
        }
    }

    // 2. Variables
    QFile varsFile(stateFilePath(QStringLiteral("vars.json")));
    if (varsFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(varsFile.readAll());
        if (doc.isObject()) {
            m_vars = doc.object().toVariantMap();
            emit varsChanged();
        }
    }

    // 3. Macros
    QFile macrosFile(stateFilePath(QStringLiteral("macros.json")));
    if (macrosFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(macrosFile.readAll());
        if (doc.isObject()) {
            m_macros = doc.object().toVariantMap();
            emit macrosChanged();
        }
    }

    // 4. Settings
    QFile setFile(stateFilePath(QStringLiteral("settings.json")));
    if (setFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(setFile.readAll());
        if (doc.isObject()) {
            const QJsonObject obj = doc.object();
            if (obj.contains(QStringLiteral("places")))
                m_places = obj.value(QStringLiteral("places")).toInt(4);
            if (obj.contains(QStringLiteral("radians")))
                m_radians = obj.value(QStringLiteral("radians")).toInt(1);
            emit settingsChanged();
        }
    }
}

void Backend::saveState() {
    const QString dirPath = stateDirectoryPath();
    QDir().mkpath(dirPath);

    // 1. History
    QFile histFile(stateFilePath(QStringLiteral("history.json")));
    if (histFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QJsonDocument doc(QJsonArray::fromVariantList(m_history));
        histFile.write(doc.toJson(QJsonDocument::Indented));
    }

    // 2. Variables
    QFile varsFile(stateFilePath(QStringLiteral("vars.json")));
    if (varsFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QJsonDocument doc(QJsonObject::fromVariantMap(m_vars));
        varsFile.write(doc.toJson(QJsonDocument::Indented));
    }

    // 3. Macros
    QFile macrosFile(stateFilePath(QStringLiteral("macros.json")));
    if (macrosFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QJsonDocument doc(QJsonObject::fromVariantMap(m_macros));
        macrosFile.write(doc.toJson(QJsonDocument::Indented));
    }

    // 4. Settings
    QFile setFile(stateFilePath(QStringLiteral("settings.json")));
    if (setFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QJsonObject obj;
        obj.insert(QStringLiteral("places"), m_places);
        obj.insert(QStringLiteral("radians"), m_radians);
        const QJsonDocument doc(obj);
        setFile.write(doc.toJson(QJsonDocument::Indented));
    }
}

void Backend::saveHistoryEntry(const QString &expr, const QString &result, bool isError) {
    if (expr.trimmed().isEmpty())
        return;

    QVariantMap entry;
    entry.insert(QStringLiteral("expr"), expr.trimmed());
    entry.insert(QStringLiteral("result"), result.trimmed());
    entry.insert(QStringLiteral("isError"), isError);
    entry.insert(QStringLiteral("time"), QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")));
    entry.insert(QStringLiteral("timestamp"), QDateTime::currentSecsSinceEpoch());

    // Insert at front
    m_history.prepend(entry);
    // Keep max 100 entries
    while (m_history.size() > 100)
        m_history.removeLast();

    emit historyChanged();
    saveState();
}

void Backend::clearHistory() {
    m_history.clear();
    emit historyChanged();
    saveState();
}

void Backend::removeHistoryEntry(int index) {
    if (index >= 0 && index < m_history.size()) {
        m_history.removeAt(index);
        emit historyChanged();
        saveState();
    }
}

void Backend::saveVar(const QString &name, const QVariant &value) {
    if (name.trimmed().isEmpty())
        return;
    m_vars.insert(name.trimmed(), value);
    emit varsChanged();
    saveState();
}

void Backend::removeVar(const QString &name) {
    if (m_vars.contains(name)) {
        m_vars.remove(name);
        emit varsChanged();
        saveState();
    }
}

void Backend::clearVars() {
    m_vars.clear();
    emit varsChanged();
    saveState();
}

void Backend::saveMacro(const QString &name, const QString &expr) {
    if (name.trimmed().isEmpty() || expr.trimmed().isEmpty())
        return;
    m_macros.insert(name.trimmed(), expr.trimmed());
    emit macrosChanged();
    saveState();
}

void Backend::removeMacro(const QString &name) {
    if (m_macros.contains(name)) {
        m_macros.remove(name);
        emit macrosChanged();
        saveState();
    }
}

void Backend::setPlaces(int p) {
    const int clamped = qBound(0, p, 18);
    if (m_places != clamped) {
        m_places = clamped;
        emit settingsChanged();
        saveState();
    }
}

void Backend::setRadians(int r) {
    const int val = r ? 1 : 0;
    if (m_radians != val) {
        m_radians = val;
        emit settingsChanged();
        saveState();
    }
}

void Backend::initEngine() {
    if (m_jsEngine)
        return;

    m_jsEngine = new QJSEngine(this);
    QStringList candidatePaths = {
        QStringLiteral(":/Engine.js"),
        QStringLiteral(":/src/Engine.js"),
        QStringLiteral("src/Engine.js"),
        QDir::currentPath() + QStringLiteral("/src/Engine.js")
    };

    bool loaded = false;
    for (const QString &path : candidatePaths) {
        QFile engineFile(path);
        if (engineFile.exists() && engineFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
            const QString code = QString::fromUtf8(engineFile.readAll());
            QJSValue val = m_jsEngine->evaluate(code, path);
            if (val.isError()) {
                std::cerr << "Engine evaluate error: " << val.toString().toStdString() << std::endl;
            } else {
                loaded = true;
            }
            break;
        }
    }

    if (!loaded) {
        std::cerr << "Warning: Could not locate Engine.js script file." << std::endl;
    }
}

bool Backend::evaluateCli(const QString &expr, bool explain, bool jsonOutput) {
    initEngine();
    if (!m_jsEngine) {
        std::cerr << "Error: Could not initialize JavaScript engine." << std::endl;
        return false;
    }

    const QString evalFnName = explain ? QStringLiteral("explainExpression") : QStringLiteral("evaluateExpression");
    QJSValue fn = m_jsEngine->globalObject().property(evalFnName);
    if (!fn.isCallable()) {
        std::cerr << "Error: evaluateExpression function not found." << std::endl;
        return false;
    }

    QJSValueList args;
    args << expr;
    args << m_jsEngine->toScriptValue(m_vars);
    args << m_places;
    args << m_radians;

    QJSValue result = fn.call(args);
    if (result.isError()) {
        std::cerr << "Evaluation Error: " << result.toString().toStdString() << std::endl;
        return false;
    }

    const QString kind = result.property(QStringLiteral("kind")).toString();
    const QString text = result.property(QStringLiteral("text")).toString();

    if (jsonOutput) {
        QJsonObject jsonObj;
        jsonObj.insert(QStringLiteral("kind"), kind);
        jsonObj.insert(QStringLiteral("text"), text);
        jsonObj.insert(QStringLiteral("expr"), expr);

        if (explain && result.hasProperty(QStringLiteral("steps"))) {
            QJsonArray stepsArr;
            QJSValue steps = result.property(QStringLiteral("steps"));
            const int len = steps.property(QStringLiteral("length")).toInt();
            for (int i = 0; i < len; ++i) {
                QJSValue s = steps.property(i);
                QJsonObject stepObj;
                stepObj.insert(QStringLiteral("expr"), s.property(QStringLiteral("expr")).toString());
                stepObj.insert(QStringLiteral("result"), s.property(QStringLiteral("result")).toString());
                stepsArr.append(stepObj);
            }
            jsonObj.insert(QStringLiteral("steps"), stepsArr);
        }

        std::cout << QJsonDocument(jsonObj).toJson(QJsonDocument::Indented).toStdString() << std::endl;
    } else {
        if (kind == QStringLiteral("error")) {
            std::cerr << "⚠️ Apple Calc Error: " << text.toStdString() << std::endl;
            return false;
        } else if (kind == QStringLiteral("silent")) {
            std::cout << "(Stored variable or setting)" << std::endl;
        } else {
            if (explain && result.hasProperty(QStringLiteral("steps"))) {
                QJSValue steps = result.property(QStringLiteral("steps"));
                const int len = steps.property(QStringLiteral("length")).toInt();
                std::cout << "🔍 Step-by-Step Evaluation:" << std::endl;
                for (int i = 0; i < len; ++i) {
                    QJSValue s = steps.property(i);
                    std::cout << "  " << (i + 1) << ". " << s.property(QStringLiteral("expr")).toString().toStdString()
                              << " = " << s.property(QStringLiteral("result")).toString().toStdString() << std::endl;
                }
                std::cout << "Final Result: " << text.toStdString() << std::endl;
            } else {
                std::cout << text.toStdString() << std::endl;
            }
        }
    }

    // Sync machine vars/settings
    if (result.hasProperty(QStringLiteral("machine"))) {
        QJSValue machine = result.property(QStringLiteral("machine"));
        if (machine.hasProperty(QStringLiteral("vars"))) {
            QJSValue vars = machine.property(QStringLiteral("vars"));
            QJSValueIterator it(vars);
            while (it.hasNext()) {
                it.next();
                m_vars.insert(it.name(), it.value().toVariant());
            }
        }
        if (machine.hasProperty(QStringLiteral("places"))) {
            m_places = machine.property(QStringLiteral("places")).toInt();
        }
        if (machine.hasProperty(QStringLiteral("radians"))) {
            m_radians = machine.property(QStringLiteral("radians")).toInt();
        }
        saveState();
    }

    return kind != QStringLiteral("error");
}
