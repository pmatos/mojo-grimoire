@fieldwise_init
struct Box(Movable):
    var v: Int


def main():
    var src: Array[Box, 1] = [Box(1)]
    var dst = List[Box](src)
    print(len(dst))
