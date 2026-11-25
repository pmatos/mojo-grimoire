@fieldwise_init
struct R(Copyable, Movable):
    var k: Int

    def __getitem__(ref self, i: Int) -> ref [self] R:
        return self

def f(r: R):
    r[0].k = 1

def main():
    f(R(1))
