
Arena :: struct {
    memory: *u8;
    used, cap: u64 = 0;
}

create_arena :: (initial_cap := COMMIT_EXPAND_AMOUNT) -> Arena {
    memory := VirtualAlloc(null, MAX_COMMITTED_SIZE, MEM_RESERVE, PAGE_READWRITE);
    if !memory fatal_error(tprint("Failed to create arena: %", GetLastError()));
    
    VirtualAlloc(memory, initial_cap, MEM_COMMIT, PAGE_READWRITE);
    
    arena: Arena;
    arena.memory = memory;
    arena.cap = initial_cap;
    return arena;
}

arena_alloc :: (arena: *Arena, size: u64) -> *void {
    if arena.used + size >= arena.cap {
        if arena.cap + COMMIT_EXPAND_AMOUNT >= MAX_COMMITTED_SIZE fatal_error("Arena exceded max committed size");
        
        remainder := size % COMMIT_EXPAND_AMOUNT;
        commit_size := size;
        if remainder != 0 commit_size += COMMIT_EXPAND_AMOUNT - remainder;
        
        VirtualAlloc(arena.memory + arena.cap, commit_size, MEM_COMMIT, PAGE_READWRITE);
        arena.cap += commit_size;
    }
    
    memory := arena.memory + arena.used;
    memset(memory, 0, xx size);
    arena.used += size;
    return memory;
}

arena_push :: (arena: *Arena, $T: Type) -> *T {
    return arena_alloc(arena, size_of(T));
}

arena_push_n :: (arena: *Arena, $T: Type, n: u64, $zero_count := false) -> [] T {
    memory := arena_alloc(arena, size_of(T) * n);
#if zero_count return .{0, memory};
    else return .{xx n, memory};
}

arena_push_mark :: (arena: *Arena) -> u64 { return arena.used; }
arena_pop_mark :: (arena: *Arena, mark: u64) { arena.used = mark; }

arena_push_mark_defer :: (arena: *Arena) #expand {
    `__arena_mark := arena_push_mark(arena);
    defer arena_pop_mark(arena, __arena_mark);
}

Typed_Arena :: struct ($T: Type) {
    using #as arena: Arena;
}

create_typed_arena :: ($T: Type, initial_cap: u64 = 128) -> Typed_Arena(T) {
    return .{create_arena(size_of(T) * initial_cap)};
}

arena_push :: (arena: *Typed_Arena($T)) -> *T {
    return arena_alloc(arena, size_of(T));
}

for_expansion :: (arena: *Typed_Arena($T), body: Code, flags: For_Flags) #expand {
    num := cast(int) (arena.used / size_of(T));
    for index: 0..num-1 {
        print("index=%\n",index);
        `it := cast (*T) (arena.memory + index * size_of(T));
        `it_index := index;
#insert body;
    }
}

init_memory_system :: () {
    working_arena = create_arena();
}

working_arena: Arena;

#scope_file

#import "Windows";

MAX_COMMITTED_SIZE :u64: 1024*1024*1024*4;
COMMIT_EXPAND_AMOUNT :u64: 1024*1024;