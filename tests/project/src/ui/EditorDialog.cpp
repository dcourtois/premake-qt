#include "EditorDialog.h"

#include <iostream>

#include "ui_EditorDialog.h"

//------------------------------------------------------------------------------
EditorDialog::EditorDialog(QWidget* parent) : QDialog(parent), ui(new Ui::EditorDialog)
{
    ui->setupUi(this);

    QObject::connect(ui->closeButton, &QPushButton::clicked, this, &EditorDialog::hello_world);
}

//------------------------------------------------------------------------------
EditorDialog::~EditorDialog()= default;

//------------------------------------------------------------------------------
void EditorDialog::hello_world()
{
    std::cout << "hello world\n";
}
