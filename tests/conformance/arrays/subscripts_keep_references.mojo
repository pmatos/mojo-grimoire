@fieldwise_init
struct T(Movable):
    var a: Array[List[Int], 1]

    def show(self):
        print(self.a[0][0], self.a[0])


def show(v: Array[List[Int], 1]):
    print(v[0][0], v[0])


def main():
    var v: Array[List[Int], 1] = [[1]]
    var z: List[Array[List[Int], 1]] = [[[2]]]
    var aa: Array[Array[Int, 1], 1] = [[3]]
    var t = T([[4]])
    print(v[0][0], v, len(v))
    print(z[0][0][0], z[0])
    print(v[0], v[0][0])
    print(v[0][v[0][0] - 1])
    show(v)
    t.show()
    print(t^.a[0][0], t^.a[0])
    ref e = v[0]
    print(e[0], e)
    ref r = v[0][0]
    print(v)
    print(r)
    r = v[0][0] + 1
    print(v[0])
    v[0][0] = v[0][0] + 1
    print(v[0], [aa[0][0]] == aa[0], v[0] == [v[0][0]])
    print(len([v[0][0]]), v[0], [v[0][0] + 0], v[0])
