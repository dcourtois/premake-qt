#include <QApplication>
#include <QFile>

#include "ui/EditorDialog.h"

QByteArray readAll(QString filename)
{
    QFile file(filename);
    file.open(QIODevice::ReadOnly);
    return file.readAll();
}

int main(int argc, char* argv[])
{
    const auto byteArray = readAll(":file.txt"); // test qrc
    if (byteArray != "hello world")
    {
        return -1;
    }
    if (argc == 1)  // Do nothing in test mode
    {
        return 0;
    }
    QApplication app(argc, argv);

    EditorDialog dialog;
    dialog.show();
    return app.exec();
}
