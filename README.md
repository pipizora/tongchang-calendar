# 同场观演日历

这是一个使用 GitHub Pages 和 Supabase 的多人实时观演日历。

## 配置 Supabase

1. 打开 Supabase 项目的 `SQL Editor`。
2. 新建查询，粘贴并运行 `supabase-setup.sql` 的全部内容。
3. 默认群邀请码是 `TONGCHANG`。
4. 在 `Authentication` -> `Providers` -> `Anonymous Sign-Ins` 中开启匿名登录。

## 发布

1. 在 GitHub 新建一个公开仓库，例如 `tongchang-calendar`。
2. 将本目录中的 `index.html`、`.nojekyll` 和 `README.md` 上传到仓库根目录。
3. 打开仓库的 `Settings` -> `Pages`。
4. 在 `Build and deployment` 中选择 `Deploy from a branch`。
5. Branch 选择 `main`，目录选择 `/ (root)`，然后点击 `Save`。
6. 等待约 1-3 分钟，公开网址通常为：

   `https://你的GitHub用户名.github.io/tongchang-calendar/`

## 使用

- 群友无需邮箱，输入昵称和邀请码 `TONGCHANG` 即可加入。
- 排期保存在 Supabase，所有群成员会看到实时更新。
- `Publishable key` 可以放在网页中；不要上传 `service_role key` 或数据库密码。
- 匿名身份保存在浏览器中；清除浏览器数据或换设备后需要重新加入。
