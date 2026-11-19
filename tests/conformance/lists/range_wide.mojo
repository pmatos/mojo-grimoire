def main():
    print("before")
    var xs = List[Int](range(-9223372036854775808, 9223372036854775807, 4611686018427387904))
    print(len(xs))
    print(xs)
    var ys = List[Int](range(9223372036854775807, -9223372036854775808, -9223372036854775808))
    print(len(ys), ys)
    var zs = List[Int](range(-9223372036854775808, 9223372036854775807, 6148914691236517205))
    print(len(zs), zs)
