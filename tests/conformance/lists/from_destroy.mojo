@fieldwise_init
struct Tag(Copyable):
    var id: Int

    def __deinit__(deinit self):
        print("gone", self.id)


def main():
    var xs = List[Tag]([Tag(1), Tag(2)])
    print("built", len(xs))
    var src: List[Tag] = [Tag(3)]
    var dst = List[Tag](src)
    print("copied")
    print(dst[0].id)
