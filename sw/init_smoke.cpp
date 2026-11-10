// C++ smoke test: class, constructor run by crt0 for a global, member functions, virtual dispatch
#define IO ((volatile unsigned *)0xC0000000u)
class Counter {
    unsigned base_, n_;
public:
    explicit Counter(unsigned base) : base_(base), n_(0) {}   // runs before main (global ctor)
    void bump(unsigned k) { n_ += k; }
    unsigned value() const { return base_ + n_; }
};
struct Shape { virtual unsigned area() const = 0; };
struct Sq : Shape { unsigned s; explicit Sq(unsigned x):s(x){} unsigned area() const override { return s*s; } };
Counter g(100);                 // global object: needs the init_array loop in crt0.S
int main() {
    int ok = 1;
    ok &= (g.value() == 100);   // constructor ran
    g.bump(5); g.bump(7);
    ok &= (g.value() == 112);
    Sq q(9); Shape *p = &q;
    ok &= (p->area() == 81);    // virtual call through the vtable in .rodata
    IO[0] = ok ? 1 : 2;
    for(;;);
}
