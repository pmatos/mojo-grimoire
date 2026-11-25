@fieldwise_init
struct S(Copyable):
    var x: Int
    def m(self, y: Int) -> Int:
        return self.x + y

def main():
    var s: S
    print(s.m(True))
