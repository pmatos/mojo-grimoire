@fieldwise_init
struct T(Movable):
    var n: Int

    def __add__(self, k: Int) -> Int:
        print("add", self.n)
        return self.n + k

    def __sub__(var self, k: Int) -> Int:
        return self.n - k

    def __deinit__(deinit self):
        print("del T", self.n)


def mk(k: Int) -> T:
    print("mk", k)
    return T(k)


def pr(k: Int) -> Int:
    print("pr", k)
    return k


def main():
    print(mk(2) + pr(1))
    print(T(5) - 1)
    print("end")
