
from clang.cindex import *
Config.set_library_path(R'D:\Work\llvm\llvm-release-assertions\bin')
from pathlib import Path
import unittest
from typing import Tuple

def get_cursor(source, spelling) -> Cursor | None:
    """Obtain a cursor from a source object.

    This provides a convenient search mechanism to find a cursor with specific
    spelling within a source. The first argument can be either a
    TranslationUnit or Cursor instance.

    If the cursor is not found, None is returned.
    """
    # Convenience for calling on a TU.
    root_cursor = source if isinstance(source, Cursor) else source.cursor

    for cursor in root_cursor.walk_preorder():
        if cursor.spelling == spelling:
            return cursor

    return None

include = Path(__file__).parent.parent.parent / 'include'
tu = TranslationUnit.from_source('fake.c', [f'-I{include}'], unsaved_files = [('fake.c', '#include "clang-c/Index.h"')])

def pythonize_name(name: str) -> str:
    if name == 'CXCursor_NonTypeTemplateParameter':
        return 'TEMPLATE_NON_TYPE_PARAMETER'
    if name == 'CXCursor_StmtExpr':
        return 'StmtExpr'
    if name == 'CXCursor_UnaryExpr':
        return 'CXX_UNARY_EXPR'
    if name == 'CXCursor_UnaryExpr':
        return 'CXX_UNARY_EXPR'
    if name == 'CXCursor_CompoundAssignOperator':
        return 'COMPOUND_ASSIGNMENT_OPERATOR'
    if name == 'CXCursor_ObjCBridgedCastExpr':
        return 'OBJC_BRIDGE_CAST_EXPR'
    if name == 'CXCursor_CXXAccessSpecifier':
        return 'CXX_ACCESS_SPEC_DECL'
    if name == 'CXCursor_MSAsmStmt':
        return 'MS_ASM_STMT'
    if name == 'CXCursor_MSAsmStmt':
        return 'OMP_PARALLELFORDIRECTIVE'
    if name == 'CXCursor_OMPTargetTeamsDistributeParallelForDirective':
        return 'OMP_DISTRIBUTE_PARALLELFORDIRECTIVE'
    if name == 'CXCursor_OMPTargetTeamsDistributeParallelForDirective':
        return 'OMP_DISTRIBUTE_PARALLELFORDIRECTIVE'
    if name == 'CXCursor_ObjCBoolLiteralExpr':
        return 'OBJ_BOOL_LITERAL_EXPR'
    if name == 'CXCursor_ObjCSelfExpr':
        return 'OBJ_SELF_EXPR'
    if name == 'CXCursor_NoDuplicateAttr':
        return 'NODUPLICATE_ATTR'
    if name == 'CXCursor_OMPTargetParallelForSimdDirective':
        return 'OMP_TARGET_PARALLEL_FOR_SIMD_DIRECTIVE'
    if name == 'CXCursor_OMPParallelForDirective':
        return 'OMP_PARALLEL_FOR_DIRECTIVE'
    if name == 'CXCursor_OMPTargetParallelForDirective':
        return 'OMP_TARGET_PARALLELFOR_DIRECTIVE'
    if name == 'CXCursor_OMPDistributeParallelForDirective':
        return 'OMP_DISTRIBUTE_PARALLELFOR_DIRECTIVE'
    if name == 'CXCursor_OMPDistributeParallelForSimdDirective':
        return 'OMP_DISTRIBUTE_PARALLEL_FOR_SIMD_DIRECTIVE'
    
    assert '_' in name
    start = name.find('_') + 1
    name = name.replace('ObjC', 'OBJC_')
    name = name.replace('CXX', 'CXX_')
    name = name.replace('SEH', 'SEH_')
    name = name.replace('OMP', 'OMP_')
    name = name.replace('GNU', 'GNU_')
    name = name.replace('IB', 'IB_')
    name = name.replace('ParallelForSimd', 'PARALLELFORSimd')
    name = name.replace('ParallelForDirective', 'ParallelForDirective'.upper())
    name = name.replace('ParallelFor', 'PARALLELFOR')

    r = str.upper(name[start])
    for k in range(start + 1, len(name)):
        if k > start + 1 and name[k].isupper() and name[k - 1].islower():
            r += '_'
        r += str.upper(name[k])
    if r.endswith("PORT"): # IMPORT/EXPORT
        r += '_ATTR'
    return r

def pythonize(cursor: Cursor) -> Tuple[str, int] | Tuple[str, str]:
    e = next(cursor.get_children())
    if e.kind == CursorKind.INTEGER_LITERAL:
        v = next(e.get_tokens()).spelling
        return pythonize_name(cursor.spelling), int(v)
    elif e.kind == CursorKind.DECL_REF_EXPR:
        v = next(e.get_tokens()).spelling
        return pythonize_name(cursor.spelling), pythonize_name(v)

    return None


class TestPythonize(unittest.TestCase):
    def test_cursorkind(self):
        self.assertEqual('CONST_ATTR', pythonize_name('CXCursor_ConstAttr'))
        self.assertEqual('OBJC_INTERFACE_DECL', pythonize_name('CXCursor_ObjCInterfaceDecl'))
        self.assertEqual('CXX_METHOD', pythonize_name('CXCursor_CXXMethod'))


class SelfDiagnoze(unittest.TestCase):
    def test_kinds(self):
        kind = get_cursor(tu, 'CXCursorKind')
        known_kinds = dict((c.name, c.value) for c in CursorKind.get_all_kinds())

        self.maxDiff = None
        declared_kinds = dict(pythonize(c) for c in kind.get_children() if pythonize(c))
        for name, alias in declared_kinds.items():
            if isinstance(alias, str):
                declared_kinds[name] = declared_kinds[alias]
        
        self.assertDictEqual(known_kinds, declared_kinds)

if __name__ == "__main__":
    unittest.main()