-- 输出样式 1, format `concise`
--[[
// Below is partial code of /project/utils.js:
function calculate(a, b) {
  return a + b;
}

// Below is partial code of /project/main.js:
const result = calculate(3, 5);

// Below is partial code of /project/helper.ts:
interface Helper {
  id: number;
  name: string;
}
...
--]]

-- 输出样式 2, format `redundant`
--[[
# Below is partical code of file:///src/user.py for the variable or function User::getName:
class User:
    def getName(self):  # Returns formatted user name
        ...
        return f"{self.last}, {self.first}"

# Below is partical code of file:///src/db/dao.py for the variable or function UserDAO::find_by_id:
class UserDAO:
    def find_by_id(self, uid):  # Core query method
        with self.conn.cursor() as cur:
            cur.execute("SELECT * FROM users WHERE id=%s", (uid,))
            ...
--]]
