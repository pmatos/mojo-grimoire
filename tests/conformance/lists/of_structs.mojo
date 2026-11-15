@fieldwise_init
struct Res(Movable):
    var id: Int

    fn __deinit__(deinit self):
        print("drop", self.id)


def main():
    var xs = List[Res]()
    xs.append(Res(1))
    xs.append(Res(2))
    print("size", len(xs))
    print("end")
