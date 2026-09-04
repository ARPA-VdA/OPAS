"""Safe evaluator for Channel["Formule"] transforms.

Formule turns a channel's raw instrument reading (x) into the real measurement
(y) - e.g. "y=x/1000" for a driver that reads millivolts but the station wants
volts. Every real value observed in this codebase's config files is a plain
linear scale ("y=x*1000", "y=x/3.6", ...), but the grammar accepted here is a
small general arithmetic expression, not just scaling.

Never uses eval()/exec()/compile(): the expression is parsed to an AST once,
walked structurally against an explicit whitelist (_validate_node), and only
then walked again to actually compute a value (_eval_node) - so a malicious or
merely wrong Formule string (attribute access, arbitrary calls, imports, ...)
is rejected outright rather than silently running. Both walks are dispatch
tables keyed by node type, same style as output_broker._ALGORITHM_HANDLERS,
so each node kind is one small, independently readable function.
"""

import ast
import math
from typing import Callable


class FormulaError(ValueError):
    """A Formule string is not a supported "y=<expr>" arithmetic expression."""


_ALLOWED_BINOPS = {
    ast.Add: lambda a, b: a + b,
    ast.Sub: lambda a, b: a - b,
    ast.Mult: lambda a, b: a * b,
    ast.Div: lambda a, b: a / b,
    ast.FloorDiv: lambda a, b: a // b,
    ast.Mod: lambda a, b: a % b,
    ast.Pow: lambda a, b: a**b,
}

_ALLOWED_UNARYOPS = {
    ast.USub: lambda a: -a,
    ast.UAdd: lambda a: +a,
}

_ALLOWED_FUNCS = {
    "abs": abs,
    "min": min,
    "max": max,
    "round": round,
    "sqrt": math.sqrt,
}


def _validate_constant(node: ast.Constant) -> None:
    if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
        raise FormulaError(f"unsupported constant: {node.value!r}")


def _validate_name(node: ast.Name) -> None:
    if node.id != "x":
        raise FormulaError(f"unknown variable '{node.id}' - only 'x' is allowed")


def _validate_binop(node: ast.BinOp) -> None:
    if type(node.op) not in _ALLOWED_BINOPS:
        raise FormulaError(f"unsupported operator: {type(node.op).__name__}")
    _validate_node(node.left)
    _validate_node(node.right)


def _validate_unaryop(node: ast.UnaryOp) -> None:
    if type(node.op) not in _ALLOWED_UNARYOPS:
        raise FormulaError(f"unsupported unary operator: {type(node.op).__name__}")
    _validate_node(node.operand)


def _validate_call(node: ast.Call) -> None:
    if not isinstance(node.func, ast.Name) or node.func.id not in _ALLOWED_FUNCS:
        raise FormulaError("unsupported function call - allowed: " + ", ".join(_ALLOWED_FUNCS))
    if node.keywords:
        raise FormulaError("keyword arguments are not supported in Formule")
    for arg in node.args:
        _validate_node(arg)


_NODE_VALIDATORS = {
    ast.Constant: _validate_constant,
    ast.Name: _validate_name,
    ast.BinOp: _validate_binop,
    ast.UnaryOp: _validate_unaryop,
    ast.Call: _validate_call,
}


def _validate_node(node: ast.AST) -> None:
    validator = _NODE_VALIDATORS.get(type(node))
    if validator is None:
        raise FormulaError(f"unsupported expression: {type(node).__name__}")
    validator(node)


def _eval_constant(node: ast.Constant, x: float) -> float:
    return node.value


def _eval_name(node: ast.Name, x: float) -> float:
    return x


def _eval_binop(node: ast.BinOp, x: float) -> float:
    op = _ALLOWED_BINOPS[type(node.op)]
    return op(_eval_node(node.left, x), _eval_node(node.right, x))


def _eval_unaryop(node: ast.UnaryOp, x: float) -> float:
    op = _ALLOWED_UNARYOPS[type(node.op)]
    return op(_eval_node(node.operand, x))


def _eval_call(node: ast.Call, x: float) -> float:
    func = _ALLOWED_FUNCS[node.func.id]
    return func(*(_eval_node(arg, x) for arg in node.args))


_NODE_EVALUATORS = {
    ast.Constant: _eval_constant,
    ast.Name: _eval_name,
    ast.BinOp: _eval_binop,
    ast.UnaryOp: _eval_unaryop,
    ast.Call: _eval_call,
}


def _eval_node(node: ast.AST, x: float) -> float:
    # Assumes _validate_node already accepted this tree - no defensive
    # FormulaError here, so a genuine runtime failure (ZeroDivisionError from
    # "y=1/x" at x=0, ValueError from sqrt(x) at x<0, ...) surfaces as itself
    # to the caller instead of being masked as a formula-shape problem.
    return _NODE_EVALUATORS[type(node)](node, x)


def parse_formula(formule: str | None) -> Callable[[float], float] | None:
    """Compiles a Channel["Formule"] string into a callable, or None if there
    is nothing to apply (missing/blank, or the "y=x" identity - the
    overwhelmingly common case, fast-pathed to skip a function call per
    reading).

    Raises FormulaError (or SyntaxError, from ast.parse) if `formule` looks
    like a "y=<expr>" assignment but `<expr>` is not a supported expression.
    A string that isn't in "y=..." shape at all (wrong left-hand side, no
    "=") is treated as "nothing to apply" rather than an error, since that
    shape is a convention, not a strict grammar this module owns.

    Never raises for the *value* fed to the returned callable - only for the
    formula text itself, at parse time. A returned callable can still raise
    at call time for values that make the expression itself undefined (e.g.
    division by zero) - that is the caller's to handle per reading.
    """
    if not formule or not formule.strip():
        return None

    text = formule.strip()
    if "=" not in text:
        return None
    lhs, _, rhs = text.partition("=")
    if lhs.strip().lower() != "y":
        return None

    rhs = rhs.strip()
    if rhs == "x":
        return None

    tree = ast.parse(rhs, mode="eval").body
    _validate_node(tree)

    def apply(x: float) -> float:
        return _eval_node(tree, x)

    return apply
