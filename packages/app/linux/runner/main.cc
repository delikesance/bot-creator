#include "my_application.h"

#include <glib.h>

static void ConfigureBundledLibraryPath()
{
  gchar *exe_path = g_file_read_link("/proc/self/exe", nullptr);
  if (exe_path == nullptr)
  {
    return;
  }

  gchar *exe_dir = g_path_get_dirname(exe_path);
  g_free(exe_path);
  if (exe_dir == nullptr)
  {
    return;
  }

  gchar *lib_dir = g_build_filename(exe_dir, "lib", nullptr);
  g_free(exe_dir);
  if (lib_dir == nullptr)
  {
    return;
  }

  const gchar *current = g_getenv("LD_LIBRARY_PATH");
  gchar *combined = nullptr;
  if (current != nullptr && *current != '\0')
  {
    combined = g_strconcat(lib_dir, ":", current, nullptr);
  }
  else
  {
    combined = g_strdup(lib_dir);
  }

  if (combined != nullptr)
  {
    g_setenv("LD_LIBRARY_PATH", combined, TRUE);
    g_free(combined);
  }

  g_free(lib_dir);
}

int main(int argc, char **argv)
{
  ConfigureBundledLibraryPath();
  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
