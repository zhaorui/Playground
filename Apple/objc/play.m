#import<Foundation/Foundation.h>

@interface HelloWorld : NSObject
- (void) hello;
@end

@implementation HelloWorld
- (void) hello {
    NSLog(@"Hello World!");
}
@end

int main(int argc, const char *argv[]){
    HelloWorld *hw = [[HelloWorld alloc] init];
    [hw hello];
    [hw release];
    return (0);
}
