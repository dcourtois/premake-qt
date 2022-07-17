#pragma once

#include <QDialog>
#include <memory>

#include "ui_EditorDialog.h"
class EditorDialog : public QDialog
{
    Q_OBJECT
public:
    explicit EditorDialog(QWidget* parent = nullptr);
    ~EditorDialog() override;

signals:
    void test_signal();

public slots:

    void hello_world();

public:
    std::unique_ptr<Ui::EditorDialog> ui;
};
