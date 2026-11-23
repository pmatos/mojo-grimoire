struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


def main():
    var t = T(1)
    var t2 = T(0)
    var r = (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or (T(2) or (T(1) or (T(0) or t and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t) and t
    print(r.n)
