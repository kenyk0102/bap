cjmp e:bool, "a", "b"
x:u32 := 0:u32

label a
x:u32 := x:u32 + 1:u32
cjmp e2:bool, "a", "b"

label b
x:u32 := x:u32 + 1:u32
