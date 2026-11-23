struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        print("bool", self.n)
        return self.n != 0


def main():
    var pi = T(1)
    var a = [1, 2]
    var zz = True
    var r = pi and (a == [[1], [2]]) and zz
    print(r)
    var s = (a < [1, [3]]) or T(0)
    print(s)
    if not T(0) and a != [[2], [2]]:
        print("yes")
