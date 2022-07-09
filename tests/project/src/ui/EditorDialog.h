#pragma once

#include <QDialog>
#include <memory>

namespace Ui
{
class EditorDialog;
}  // namespace Ui

class EditorDialog : public QDialog
{
    Q_OBJECT
   public:
    explicit EditorDialog(QWidget* parent= nullptr);
    ~EditorDialog();

   public slots:

    void hello_world();

   private:
    std::unique_ptr<Ui::EditorDialog> ui;
};
