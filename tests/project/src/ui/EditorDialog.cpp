#include "EditorDialog.h"

#include <iostream>

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
    ui->label->setText("hello world");
    std::cout << "hello world\n";
}
