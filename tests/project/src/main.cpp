#include <QApplication>

#include "ui/EditorDialog.h"

int main(int argc, char* argv[])
{
    if(argc == 1)  // Do nothing in test mode
    {
	return 0;
    }
    QApplication app(argc, argv);

    EditorDialog dialog;
    dialog.show();
    return app.exec();
}
