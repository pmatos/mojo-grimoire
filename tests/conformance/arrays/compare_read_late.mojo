def bump(mut a: Array[Int, 1]) -> Array[Int, 1]:
    a[0] = 5
    return [5]


def main():
    var a = [1]
    print(a == bump(a))
    var b = [2]
    print(bump(b) == b, b[0])
