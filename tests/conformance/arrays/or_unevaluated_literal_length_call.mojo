def f(k: Int) -> Int:
    print("f", k)
    return k


def main():
    var t = True
    print(t or ([f(2), 1] < [[2, 0], [2, 0]]))
    print("end")
