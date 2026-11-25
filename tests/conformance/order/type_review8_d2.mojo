@fieldwise_init
struct W(Copyable):
    var n: Int
    def __getitem__(self, i: Int) -> Int:
        return self.n

def g(x: Int) -> Int:
    return x

def inc(mut x: Int):
    x += 1

def main():
    var n: Int = 5
    var u: Int
    var ws: List[W] = [W(1)]
    ref r = ws[0]
    ws.append(W(2))
    print(r[g(u)])
