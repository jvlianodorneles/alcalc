#pragma once

#include <QColor>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class QWindow;
class QJSEngine;
class QFileSystemWatcher;

class Backend : public QObject {
    Q_OBJECT

    Q_PROPERTY(bool darkMode READ darkMode WRITE setDarkMode NOTIFY darkModeChanged)
    Q_PROPERTY(qreal textScale READ textScale WRITE setTextScale NOTIFY textScaleChanged)
    Q_PROPERTY(bool popupMode READ popupMode WRITE setPopupMode NOTIFY popupModeChanged)
    Q_PROPERTY(QColor themeBackground READ themeBackground NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeForeground READ themeForeground NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeSurface READ themeSurface NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeSurfaceVariant READ themeSurfaceVariant NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeAccent READ themeAccent NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeBorder READ themeBorder NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeSelection READ themeSelection NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeMuted READ themeMuted NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeError READ themeError NOTIFY themeColorsChanged)
    Q_PROPERTY(QColor themeSuccess READ themeSuccess NOTIFY themeColorsChanged)

    Q_PROPERTY(QVariantList historyList READ historyList NOTIFY historyChanged)
    Q_PROPERTY(QVariantMap varsMap READ varsMap NOTIFY varsChanged)
    Q_PROPERTY(QVariantMap macrosMap READ macrosMap NOTIFY macrosChanged)
    Q_PROPERTY(int places READ places WRITE setPlaces NOTIFY settingsChanged)
    Q_PROPERTY(int radians READ radians WRITE setRadians NOTIFY settingsChanged)

public:
    explicit Backend(QObject *parent = nullptr);
    ~Backend() override;

    bool darkMode() const { return m_darkMode; }
    void setDarkMode(bool darkMode);

    qreal textScale() const { return m_textScale; }
    void setTextScale(qreal textScale);

    bool popupMode() const { return m_popupMode; }
    void setPopupMode(bool popupMode);

    QColor themeBackground() const;
    QColor themeForeground() const;
    QColor themeSurface() const;
    QColor themeSurfaceVariant() const;
    QColor themeAccent() const;
    QColor themeBorder() const;
    QColor themeSelection() const;
    QColor themeMuted() const;
    QColor themeError() const;
    QColor themeSuccess() const;

    QVariantList historyList() const { return m_history; }
    QVariantMap varsMap() const { return m_vars; }
    QVariantMap macrosMap() const { return m_macros; }
    int places() const { return m_places; }
    int radians() const { return m_radians; }

    void setParentWindow(QWindow *window) { m_parentWindow = window; }
    QWindow *parentWindow() const { return m_parentWindow; }

    Q_INVOKABLE void copyToClipboard(const QString &text);
    Q_INVOKABLE void saveHistoryEntry(const QString &expr, const QString &result, bool isError = false);
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void removeHistoryEntry(int index);

    Q_INVOKABLE void saveVar(const QString &name, const QVariant &value);
    Q_INVOKABLE void removeVar(const QString &name);
    Q_INVOKABLE void clearVars();

    Q_INVOKABLE void saveMacro(const QString &name, const QString &expr);
    Q_INVOKABLE void removeMacro(const QString &name);

    Q_INVOKABLE void setPlaces(int p);
    Q_INVOKABLE void setRadians(int r);

    Q_INVOKABLE QString stateDirectoryPath() const;
    Q_INVOKABLE void loadState();
    Q_INVOKABLE void saveState();

    bool evaluateCli(const QString &expr, bool explain, bool jsonOutput);

signals:
    void darkModeChanged(bool darkMode);
    void textScaleChanged(qreal textScale);
    void popupModeChanged(bool popupMode);
    void themeColorsChanged();
    void historyChanged();
    void varsChanged();
    void macrosChanged();
    void settingsChanged();

private:
    void initEngine();
    void setupStateWatcher();
    QString stateFilePath(const QString &filename) const;

    bool m_darkMode = true;
    qreal m_textScale = 1.0;
    bool m_popupMode = false;
    bool m_isSavingState = false;
    int m_places = 4;
    int m_radians = 1;

    QVariantList m_history;
    QVariantMap m_vars;
    QVariantMap m_macros;

    QWindow *m_parentWindow = nullptr;
    QJSEngine *m_jsEngine = nullptr;
    QFileSystemWatcher *m_fileWatcher = nullptr;
};
