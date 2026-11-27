struct T(Copyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Int:
        return self.n

def main():
    var t2 = T(1)
    var r = T(3) or t2
