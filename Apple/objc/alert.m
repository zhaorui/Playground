#import <Cocoa/Cocoa.h>

int main(int argc, char *argv[])
{
   /*NSBeginInformationalAlertSheet(
                                   "Centrify uninstalled",
                                   "OK",nil,nil,
                                   [[self mainView] window], self, 
                                   @selector(alertDidEnd:returnCode:contextInfo:), 
                                   nil,
                                   nil, 
                                   text
                                   ); 
    return 0;*/
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert setMessageText:@"Delete the record?"];
    [alert setInformativeText:@"Deleted records cannot be restored."];
    [alert setAlertStyle:NSWarningAlertStyle];
}
