from __future__ import annotations

import pickle

import copy
import cProfile
import itertools
import random
from enum import Enum

import numpy as np
from tqdm import tqdm

# ------------------ 游戏全局配置 ------------------


class Stage(Enum):
    ACTIVATE = 0
    MOVE = 1
    ATTACK = 2


# ------------------ 核心数据结构 ------------------
class Block:

    def __init__(self, name: str, faction, x: int, y: int, z: int):
        self.name = name
        self.x = x
        self.y = y
        self.z = z
        self.faction = faction
        self.neighbours = []

    def get_distance(self, block: Block) -> int:
        return (
            abs(self.x - block.x) + abs(self.y - block.y) + abs(self.z - block.z)
        ) / 2

    def get_neighbours(self, blocks) -> list[Block]:
        neighbours = []
        for block in blocks:
            if self.get_distance(block) == 1:
                neighbours.append(block)
        return neighbours

    @staticmethod
    def get_by_name(blocks, name: str) -> Block:
        for block in blocks:
            if block.name == name:
                return block


class Pawn:
    def __init__(self, pawn_id, location, faction, is_activated=False, is_moved=False):
        self.pawn_id = pawn_id
        self.faction = faction
        self.is_activated = is_activated
        self.is_moved = is_moved
        self.location = location


class Player:
    def __init__(self, faction, score):
        self.faction = faction
        self.score = score


class Node:
    """蒙特卡洛树节点"""

    def __init__(self, parent=None, leading_action=None):
        self.visits = 0  # 访问次数
        self.value = 0.0  # 累计价值
        self.prior_prob = 0.0  # 先验概率
        self.children = []  # 子节点列表
        self.untried = None  # 未尝试动作列表
        self.parent = parent
        self.leading_action = leading_action

    def is_fully_expanded(self):
        return len(self.untried) == 0 and len(self.children) != 0

    def is_leaf(self):
        return len(self.children) == 0


class Tree:
    """玩家独立决策树"""

    def __init__(self, player, game):
        self.game = game
        self.player = player
        self.root = Node()  # 当前根节点
        self.exploration = 1.414  # UCT探索系数
        self.current_node = self.root

    def update_current_node(self, action):
        """更新当前节点（被动节点处理）"""
        for child in self.current_node.children:
            if child.leading_action == action:
                self.current_node = child
                return
        node = Node(
            parent=self.current_node,
            leading_action=action,
        )
        self.current_node.children.append(node)
        self.current_node = node


# ------------------ 游戏状态实现 ------------------
class Game:
    def __init__(
        self,
        stage=Stage.ACTIVATE,
        game_round=0,
        max_activation=2,
        players=None,
        pawns=None,
        blocks=None,
        current_player="ally",
    ):
        if players is None:
            players = {"ally": Player("ally", 0), "axis": Player("axis", 0)}
        if blocks is None:
            blocks = [
                Block("paris", "neutral", -1, 2, -1),
                Block("amiens", "ally", 0, 2, -2),
                Block("le cateau", "ally", 1, 1, -2),
                Block("liege", "axis", 2, 0, -2),
                Block("luxembourg", "axis", 2, -1, -1),
                Block("melun", "neutral", -1, 1, 0),
                Block("soissons", "neutral", 0, 1, -1),
                Block("sedan", "neutral", 1, 0, -1),
                Block("verdun", "neutral", 1, -1, 0),
                Block("langres", "neutral", 0, -1, 1),
                Block("troyes", "neutral", -1, 0, 1),
                Block("chalons", "neutral", 0, 0, 0),
            ]

        if pawns is None:
            pawns = [
                Pawn(0, "amiens", "ally"),
                Pawn(1, "le cateau", "ally"),
                Pawn(2, "sedan", "ally"),
                Pawn(3, "sedan", "ally"),
                Pawn(4, "sedan", "ally"),
                Pawn(5, "verdun", "ally"),
                Pawn(6, "verdun", "ally"),
                Pawn(7, "verdun", "ally"),
                Pawn(8, "liege", "axis", True),
                Pawn(9, "liege", "axis", True),
                Pawn(10, "liege", "axis"),
                Pawn(11, "liege", "axis"),
                Pawn(12, "liege", "axis"),
                Pawn(13, "luxembourg", "axis", True),
                Pawn(14, "luxembourg", "axis", True),
                Pawn(15, "luxembourg", "axis"),
            ]
        self.round = game_round
        self.stage = stage
        self.max_activation = max_activation
        self.players = players
        self.blocks = blocks
        for block in blocks:
            block.neighbours = block.get_neighbours(self.blocks)
        self.pawns = pawns
        self.current_player = current_player

    def get_allowed_actions(self, faction) -> list[dict]:
        actions = []
        if self.stage == Stage.ACTIVATE:
            activable = [
                pawn.pawn_id
                for pawn in self.pawns
                if not pawn.is_activated and pawn.faction == faction
            ]
            for t in list(
                itertools.combinations(
                    activable,
                    min(self.max_activation, len(activable)),
                )
            ):
                actions.append(
                    {"player": faction, "action": "activate", "targets": list(t)}
                )

        elif self.stage == Stage.MOVE:
            movable = [
                (pawn.pawn_id, pawn.location)
                for pawn in self.pawns
                if not pawn.is_moved and pawn.faction == faction
            ]
            choices = []
            for _ in movable:
                possible = []
                for neighbour in Block.get_by_name(self.blocks, _[1]).neighbours:
                    if neighbour.faction in (faction, "neutral"):
                        possible.append({_[0]: neighbour.name})
                possible.append({_[0]: None})
                choices.append(possible)
            for choice in list(itertools.product(*choices)):
                targets = {}
                for _ in choice:
                    targets |= _
                actions.append(
                    {"player": faction, "action": "move", "targets": targets}
                )

        elif self.stage == Stage.ATTACK:
            attackable = [
                pawn.location
                for pawn in self.pawns
                if not pawn.is_moved and pawn.is_activated and pawn.faction == faction
            ]
            choices = []
            for _ in attackable:
                possible = []
                for neighbour in Block.get_by_name(self.blocks, _).neighbours:
                    if neighbour.faction != faction or neighbour.faction == "neutral":
                        possible.append({_: neighbour.name})
                possible.append({_: None})
                choices.append(possible)
            for choice in list(itertools.product(*choices)):
                targets = {}
                for _ in choice:
                    targets |= _
                actions.append(
                    {"player": faction, "action": "attack", "targets": targets}
                )

        return actions

    def apply_action(self, action) -> "Game":
        opponent = "ally" if action["player"] == "axis" else "axis"
        if action["action"] == "activate":
            for pawn in self.pawns:
                if (
                    pawn.faction == action["player"]
                    and pawn.pawn_id in action["targets"]
                ):
                    pawn.is_activated = True
        elif action["action"] == "move":
            for pawn in self.pawns:
                if (
                    pawn.faction == action["player"]
                    and pawn.pawn_id in action["targets"]
                ):
                    if action["targets"][pawn.pawn_id] is not None:
                        pawn.location = action["targets"][pawn.pawn_id]
            for block in self.blocks:
                if (
                    len(
                        {
                            pawn.faction
                            for pawn in self.pawns
                            if pawn.location == block.name
                        }
                    )
                    == 2
                    or len(
                        {
                            pawn.faction
                            for pawn in self.pawns
                            if pawn.location == block.name
                        }
                    )
                    == 0
                ):
                    block.faction = "neutral"
                else:
                    block.faction = {
                        pawn.faction
                        for pawn in self.pawns
                        if pawn.location == block.name
                    }.pop()
                    self.players[action["player"]].score += 1
                    if action["player"] == "axis" and block.name == "paris":
                        self.players[action["player"]].score = np.inf

        elif action["action"] == "attack":

            attack_count = {}
            for k, v in action["targets"].items():
                if v is not None:
                    if v in attack_count:
                        attack_count[v].append(k)
                    else:
                        attack_count[v] = [k]
            for k, v in attack_count.items():
                attackers = [
                    pawn
                    for pawn in self.pawns
                    if pawn.faction == action["player"]
                    and pawn.location in v
                    and pawn.is_activated
                    and not pawn.is_moved
                ]
                defenders = [
                    pawn
                    for pawn in self.pawns
                    if pawn.faction != action["player"]
                    and pawn.location == k
                    and pawn.is_activated
                ]
                if len(attackers) >= len(defenders):
                    if len(defenders) != 0:
                        for defender in defenders:
                            self.pawns.remove(defender)
                    for attacker in attackers:
                        attacker.location = k
                        attacker.is_activated = False
                    self.players[action["player"]].score += len(defenders)
                    Block.get_by_name(self.blocks, k).faction = action["player"]
                    self.players[action["player"]].score += 1
                    self.players[opponent].score -= 1
                    self.players[opponent].score -= len(defenders)
                    if action["player"] == "axis" and k == "paris":
                        self.players[action["player"]].score = np.inf
                else:
                    for defender in defenders[: len(attackers)]:
                        defender.is_activated = False
                    for attacker in attackers:
                        attacker.is_activated = False
        self.progress()
        return self

    def copy(self, player) -> "Game":
        return Game(
            stage=self.stage,
            game_round=self.round,
            players=copy.deepcopy(self.players),
            pawns=copy.deepcopy(
                [pawn for pawn in self.pawns if pawn.faction == player]
            ),
            blocks=copy.deepcopy(self.blocks),
        )

    def is_terminal(self) -> bool:
        return (
            self.round == 5
            or Block.get_by_name(self.blocks, "paris").faction == "axis"
            or len({pawn.faction for pawn in self.pawns}) == 1
        )

    def progress(self):
        if self.current_player == "ally":
            self.current_player = "axis"
        else:
            self.current_player = "ally"
            if self.stage == Stage.ACTIVATE:
                self.stage = Stage.MOVE
            elif self.stage == Stage.MOVE:
                self.stage = Stage.ATTACK
            elif self.stage == Stage.ATTACK:
                self.stage = Stage.ACTIVATE
                self.round += 1

    def get_reward(self, faction) -> int:
        opponent = "ally" if faction == "axis" else "axis"
        return self.players[faction].score - self.players[opponent].score


# ------------------ 主算法实现 ------------------
def mo_ismcts(global_game: Game, iterations=1000):
    """多观察者ISMCTS主函数"""
    # 初始化组件
    game = copy.deepcopy(global_game)
    trees = {"ally": Tree("ally", game), "axis": Tree("axis", game)}
    for _ in tqdm(range(iterations)):
        while not game.is_terminal():
            current_tree = trees[game.current_player]
            while not current_tree.current_node.is_leaf():
                action = None
                if current_tree.current_node.is_fully_expanded():
                    action = uct_select(current_tree.current_node)
                else:
                    action = current_tree.current_node.untried.pop()
                game.apply_action(action)
                for tree in trees.values():
                    tree.update_current_node(action)
                current_tree = trees[game.current_player]
            if game.round != 5:
                current_tree.current_node.untried = game.get_allowed_actions(
                    game.current_player
                )
                random.shuffle(current_tree.current_node.untried)
                action = current_tree.current_node.untried.pop()
                game.apply_action(action)
                for tree in trees.values():
                    tree.update_current_node(action)
            sim_game = copy.deepcopy(game)
            while not sim_game.is_terminal():
                actions = sim_game.get_allowed_actions(sim_game.current_player)

                sim_game.apply_action(random.choice(actions))
            node = current_tree.current_node
            while node:
                node.visits += 1
                node.value += sim_game.get_reward(game.current_player)
                node = node.parent

        for tree in trees.values():
            tree.current_node = tree.root
        game = copy.deepcopy(global_game)
    for k, v in trees.items():
        save_tree(v, k)
    current_player = global_game.current_player
    best_action = max(
        trees[current_player].root.children, key=lambda x: x.visits
    ).leading_action
    return best_action


# 序列化
def save_tree(tree, filename):
    with open(filename, "wb") as f:
        pickle.dump(tree, f, protocol=pickle.HIGHEST_PROTOCOL)


# 反序列化
def load_tree(filename):
    with open(filename, "rb") as f:
        return pickle.load(f)


# ------------------ 算法阶段实现 ------------------
def uct_select(node: Node):
    """UCT动作选择"""
    best_score = -np.inf
    best_local_action = None
    for child in node.children:
        score = child.value / (child.visits + 1e-6) + np.sqrt(
            np.log(node.visits + 1) / (child.visits + 1e-6)
        )
        if score > best_score:
            best_score = score
            best_local_action = child.leading_action
    return best_local_action



# ------------------ 使用示例 ------------------
if __name__ == "__main__":
    # 初始化游戏
    inital_game = Game()

    # 运行算法

    profiler = cProfile.Profile()
    profiler.enable()
    optimal_action = mo_ismcts(inital_game, 1000)
    profiler.disable()
    profiler.print_stats()
    print(f"玩家{inital_game.current_player}的最佳动作：{optimal_action}")
