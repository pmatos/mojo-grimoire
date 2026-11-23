struct T(ImplicitlyCopyable):
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def __bool__(self) -> Bool:
        return self.n != 0


def idT(x: T) -> T:
    return x


def main():
    var a = T(0)
    var b = T(2)
    var r = idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((idT((a or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b)) or b))
    print(r.n)
