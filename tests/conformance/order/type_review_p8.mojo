@fieldwise_init
struct A(Movable):
    var b: B

@fieldwise_init
struct B(Movable):
    var a: A
    def m(self):
        print(zz)

def main():
    print(1)
