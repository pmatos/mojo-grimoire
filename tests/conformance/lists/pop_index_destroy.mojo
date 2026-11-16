@fieldwise_init
struct Res(Movable):
    var id: Int

    def __deinit__(deinit self):
        print("drop", self.id)


def main():
    var rs: List[Res] = [Res(1), Res(2), Res(3)]
    var r = rs.pop(0)
    print("popped", r.id, len(rs))
    rs.pop(1)
    print("after discard", len(rs))
    print("end", r.id)
